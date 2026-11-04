//
//  PublicProfileStore.swift
//  Bullish Square
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

///What other people can see of an account, apart from `users/{uid}`, which keeps the email
///and phone and stays readable by its owner only. The groundwork for the social features:
///Bulls, Apprentices and anyone else need to find and show each other. (BS-257)
///
///- `profiles/{uid}`: public fields only (username, name; the photo, bio and the rest come
///  with BS-258 and BS-259). Any signed-in user reads it; only its owner writes it.
///- `usernames/{handle}` -> `{uid}`: one document per handle, claimed in a transaction, so
///  two accounts cannot hold the same one.
///
///Rules live only in the Firebase console, like the rest (PROJECT.md §6).
final class PublicProfileStore {

    // MARK: - Properties

    static let shared = PublicProfileStore()
    private init() {}

    static let minimumLength = 3
    static let maximumLength = 20

    private var profiles: CollectionReference { Firestore.firestore().collection("profiles") }
    private var usernames: CollectionReference { Firestore.firestore().collection("usernames") }

    enum UsernameError: LocalizedError {
        case invalid
        case taken
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .invalid:
                return "A username is \(PublicProfileStore.minimumLength) to \(PublicProfileStore.maximumLength) letters, numbers or underscores."
            case .taken:
                return "That username is taken. Try another one."
            case .notSignedIn:
                return "Sign in to choose a username."
            }
        }
    }

    // MARK: - Usernames

    ///As typed, to as stored: no spaces, no leading "@", lower case, so "@Javier" and
    ///"javier" are one handle.
    static func normalized(_ text: String) -> String {
        var handle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while handle.hasPrefix("@") { handle.removeFirst() }
        return handle.lowercased()
    }

    static func isValid(_ handle: String) -> Bool {
        (minimumLength...maximumLength).contains(handle.count)
            && handle.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
    }

    ///Takes `handle` for the signed-in account and frees the one it had. In a transaction,
    ///so a handle claimed by someone else between the check and the write is refused.
    func claimUsername(_ handle: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(UsernameError.notSignedIn))
            return
        }
        guard Self.isValid(handle) else {
            completion(.failure(UsernameError.invalid))
            return
        }
        let handleRef = usernames.document(handle)
        let profileRef = profiles.document(uid)
        let usernames = self.usernames

        Firestore.firestore().runTransaction({ transaction, errorPointer in
            do {
                //Reads before any write, as a transaction requires.
                let claimed = try transaction.getDocument(handleRef)
                let profile = try transaction.getDocument(profileRef)
                if claimed.exists, claimed.data()?["uid"] as? String != uid {
                    errorPointer?.pointee = UsernameError.taken as NSError
                    return nil
                }
                let previous = profile.data()?["username"] as? String
                guard previous != handle else { return nil }
                if let previous, !previous.isEmpty {
                    transaction.deleteDocument(usernames.document(previous))
                }
                transaction.setData(["uid": uid], forDocument: handleRef)
                transaction.setData(["username": handle, "updatedAt": FieldValue.serverTimestamp()],
                                    forDocument: profileRef, merge: true)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }) { _, error in
            //A handle taken by a write that raced this one is caught by the transaction, which
            //retries and then reads it as taken. Permission denied means the rules refused, and
            //is reported as itself, not as "taken", so it is not retried with new digits.
            if let error = error as NSError? {
                if (error as Error) as? UsernameError == .taken {
                    completion(.failure(UsernameError.taken))
                } else {
                    print("Claiming the username \(handle) failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            completion(.success(()))
        }
    }

    ///Picked from at sign-up, so every account has a handle from the start: an animal and a
    ///few digits, "bull_4821". Changeable later.
    static let animals = ["bull", "bear", "hawk", "owl", "fox", "wolf", "eagle", "otter", "lynx", "falcon",
                          "tiger", "panda", "koala", "orca", "raven", "bison", "heron", "badger", "puma", "stag"]

    static func randomUsername() -> String {
        "\(animals.randomElement() ?? "bull")_\(Int.random(in: 100...9999))"
    }

    ///Gives the signed-in account a generated handle when it has none: new accounts at
    ///sign-up, older ones the first time they open the profile. A taken one is retried with
    ///new digits, a few times. Calls back with the handle it holds, or nil.
    func ensureUsername(completion: ((String?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(nil)
            return
        }
        loadProfile(uid: uid) { [weak self] profile in
            guard let self else { return }
            if let username = profile?.username, !username.isEmpty {
                completion?(username)
                return
            }
            self.claimGenerated(attemptsLeft: 5, completion: completion)
        }
    }

    private func claimGenerated(attemptsLeft: Int, completion: ((String?) -> Void)?) {
        let handle = Self.randomUsername()
        claimUsername(handle) { [weak self] result in
            switch result {
            case .success:
                completion?(handle)
            case .failure(UsernameError.taken) where attemptsLeft > 1:
                self?.claimGenerated(attemptsLeft: attemptsLeft - 1, completion: completion)
            case .failure:
                completion?(nil)
            }
        }
    }

    // MARK: - Profile

    ///The public copy of an account, as other people will see it.
    struct PublicProfile {
        var username: String?
        var name: String?
        var bio: String?
        var memberSince: Date?
    }

    ///nil when it could not be read; empty fields when the account has none yet.
    func loadProfile(uid: String, completion: @escaping (PublicProfile?) -> Void) {
        profiles.document(uid).getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Loading the public profile failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            let data = snapshot?.data() ?? [:]
            completion(PublicProfile(username: data["username"] as? String,
                                     name: data["name"] as? String,
                                     bio: data["bio"] as? String,
                                     memberSince: (data["memberSince"] as? Timestamp)?.dateValue()))
        }
    }

    ///Copies the name to the public profile. Fire and forget: the private save already
    ///succeeded, and the next Settings load tries again when the two differ.
    func publish(name: String) {
        guard let user = Auth.auth().currentUser else { return }
        var data: [String: Any] = ["name": name, "updatedAt": FieldValue.serverTimestamp()]
        if let created = user.metadata.creationDate {
            data["memberSince"] = Timestamp(date: created)
        }
        profiles.document(user.uid).setData(data, merge: true) { error in
            if let error = error as NSError? {
                print("Publishing the profile name failed: \(error.localizedDescription)")
            }
        }
    }

    ///Account deletion: the profile and the handle it holds, so the handle is free again.
    func deleteProfile(uid: String, completion: @escaping (Error?) -> Void) {
        let profileRef = profiles.document(uid)
        profileRef.getDocument { [usernames] snapshot, error in
            if let error {
                completion(error)
                return
            }
            let batch = Firestore.firestore().batch()
            if let handle = snapshot?.data()?["username"] as? String, !handle.isEmpty {
                batch.deleteDocument(usernames.document(handle))
            }
            batch.deleteDocument(profileRef)
            batch.commit { error in
                completion(error)
            }
        }
    }
}
