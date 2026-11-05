//
//  AuthorDirectory.swift
//  Bullish Square
//

import UIKit

///Public profiles of the people on screen, read once each and kept for the session, so a
///feed of 20 posts by 5 people reads 5 profiles. (BS-266)
final class AuthorDirectory {

    // MARK: - Properties

    static let shared = AuthorDirectory()
    private init() {}

    private var profiles: [String: PublicProfileStore.PublicProfile] = [:]

    func profile(_ uid: String) -> PublicProfileStore.PublicProfile? {
        profiles[uid]
    }

    ///"@wolf_7908", or "Member" for a profile not read yet or without a username.
    func handle(_ uid: String) -> String {
        profiles[uid]?.username.map { "@\($0)" } ?? "Member"
    }

    ///False for a profile not read yet, so a bot shows its badge once its profile is loaded,
    ///which the feeds wait for before showing a post. (BS-279)
    func isAutomated(_ uid: String) -> Bool {
        profiles[uid]?.isAutomated == true
    }

    ///The name, or the handle when there is none.
    func displayName(_ uid: String) -> String {
        if let name = profiles[uid]?.name, !name.isEmpty { return name }
        return handle(uid)
    }

    ///Reads the ones not known yet. Calls back once, on the main queue, when all have
    ///answered; one that fails just stays unknown.
    func load(_ uids: [String], completion: @escaping () -> Void) {
        let missing = Set(uids).subtracting(profiles.keys)
        guard !missing.isEmpty else { return completion() }
        let group = DispatchGroup()
        for uid in missing {
            group.enter()
            PublicProfileStore.shared.loadProfile(uid: uid) { [weak self] profile in
                DispatchQueue.main.async {
                    if let profile { self?.profiles[uid] = profile }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    ///After following someone or editing your own profile, so the next read is fresh.
    func forget(_ uid: String) {
        profiles[uid] = nil
    }

    ///On pull to refresh: everyone is read again, so a changed name or photo shows.
    func forgetAll() {
        profiles.removeAll()
    }
}

///Pictures from URLs - avatars and post photos - kept in memory while the app runs.
final class RemoteImageCache {

    static let shared = RemoteImageCache()
    private init() {
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    private let cache = NSCache<NSString, UIImage>()

    func cached(_ url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    ///Calls back on the main queue with the image, or nil when it can't be loaded.
    func load(_ url: String, completion: @escaping (UIImage?) -> Void) {
        if let image = cached(url) { return completion(image) }
        guard let address = URL(string: url) else { return completion(nil) }
        URLSession.shared.dataTask(with: address) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image, let data {
                self?.cache.setObject(image, forKey: url as NSString, cost: data.count)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}
