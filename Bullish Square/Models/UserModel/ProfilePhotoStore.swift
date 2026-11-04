//
//  ProfilePhotoStore.swift
//  Bullish Square
//

import UIKit
import CoreData
import FirebaseAuth
import FirebaseStorage

///The profile photo, per account: in Cloud Storage at `profilePhotos/{uid}/avatar.jpg`, its
///download URL on `profiles/{uid}.photoURL`, and a copy in Caches keyed by uid. (BS-258)
///
///It replaces ProfileEntity, one Core Data photo that belonged to nobody: it survived
///sign-out, so the next account on the phone showed the last one's photo, and it never
///reached a new phone or anyone else.
final class ProfilePhotoStore {

    // MARK: - Properties

    static let shared = ProfilePhotoStore()
    private init() {}

    ///Plenty for a 96 pt circle at 3x, and small enough to upload on a slow connection.
    static let maximumSide: CGFloat = 512
    static let jpegQuality: CGFloat = 0.8
    ///Matches the Storage rule.
    static let maximumBytes: Int64 = 2 * 1024 * 1024

    enum PhotoError: LocalizedError {
        case notSignedIn
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Sign in to set a profile photo."
            case .unreadable: return "That photo couldn't be read. Try another one."
            }
        }
    }

    private func reference(_ uid: String) -> StorageReference {
        Storage.storage().reference().child("profilePhotos/\(uid)/avatar.jpg")
    }

    // MARK: - Cache

    private func cacheURL(_ uid: String) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = caches.appendingPathComponent("profilePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(uid).jpg")
    }

    ///This account's photo as last seen on this phone, or nil.
    func cachedPhoto(uid: String) -> UIImage? {
        guard let url = cacheURL(uid), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    ///Which URL the cached copy came from, so a photo changed on another phone is fetched.
    private func cachedURLKey(_ uid: String) -> String { "profilePhotoURL_\(uid)" }

    private func cache(_ data: Data, uid: String, from urlString: String) {
        guard let url = cacheURL(uid) else { return }
        do {
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.set(urlString, forKey: cachedURLKey(uid))
        } catch let error as NSError {
            print("Caching the profile photo failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload and download

    ///Resizes, uploads, publishes the URL, then caches. Calls back once, on the main queue,
    ///with nil or the error.
    func upload(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        let done: (Error?) -> Void = { error in DispatchQueue.main.async { completion(error) } }
        guard let uid = Auth.auth().currentUser?.uid else { return done(PhotoError.notSignedIn) }
        guard let data = Self.jpegData(image) else { return done(PhotoError.unreadable) }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let ref = reference(uid)
        ref.putData(data, metadata: metadata) { [weak self] _, error in
            if let error = error as NSError? {
                print("Uploading the profile photo failed: \(error.localizedDescription)")
                return done(error)
            }
            ref.downloadURL { url, error in
                guard let url else {
                    print("Reading the profile photo URL failed: \(error?.localizedDescription ?? "no URL")")
                    return done(error ?? PhotoError.unreadable)
                }
                PublicProfileStore.shared.update(["photoURL": url.absoluteString]) { error in
                    if error == nil { self?.cache(data, uid: uid, from: url.absoluteString) }
                    done(error)
                }
            }
        }
    }

    ///Fetches the photo at `urlString` when the cached copy is missing or from another URL.
    ///Calls back once, on the main queue, with the new photo, or nil when nothing changed or
    ///it could not be fetched.
    func refresh(uid: String, urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString, let url = URL(string: urlString),
              urlString != UserDefaults.standard.string(forKey: cachedURLKey(uid)) || cachedPhoto(uid: uid) == nil else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data, let image = UIImage(data: data) else {
                print("Downloading the profile photo failed: \(error?.localizedDescription ?? "not an image")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.cache(data, uid: uid, from: urlString)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    ///Square-cropped from the centre, scaled down to maximumSide, as JPEG.
    static func jpegData(_ image: UIImage) -> Data? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let target = min(side, maximumSide)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let scaled = renderer.image { _ in
            let scale = target / side
            image.draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        return scaled.jpegData(compressionQuality: jpegQuality)
    }

    // MARK: - Deletion

    ///Account deletion. A photo that was never uploaded is not an error.
    func delete(uid: String, completion: @escaping (Error?) -> Void) {
        if let url = cacheURL(uid) { try? FileManager.default.removeItem(at: url) }
        UserDefaults.standard.removeObject(forKey: cachedURLKey(uid))
        reference(uid).delete { error in
            if let error = error as NSError?, error.domain == StorageErrorDomain,
               error.code == StorageErrorCode.objectNotFound.rawValue {
                return completion(nil)
            }
            completion(error)
        }
    }

    ///Drops the Core Data photo that belonged to nobody. Not uploaded: which account it was
    ///is unknowable, and it could be somebody else's. Once per install.
    func removeLegacyPhoto() {
        let key = "profilePhotoLegacyRemoved"
        guard !UserDefaults.standard.bool(forKey: key),
              let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        do {
            for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ProfileEntity")) {
                context.delete(object)
            }
            if context.hasChanges { try context.save() }
            UserDefaults.standard.set(true, forKey: key)
        } catch let error as NSError {
            print("Removing the old device-only profile photo failed: \(error.localizedDescription)")
        }
    }
}
