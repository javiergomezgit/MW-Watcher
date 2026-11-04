//
//  AccountProfileStore.swift
//  Bullish Square
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

///The private side of the profile, `users/{uid}`: name, email and phone, readable by its owner
///only. The public side is PublicProfileStore. Moved out of the old Settings and Edit Profile
///screens, which each talked to Firestore themselves. (BS-260)
final class AccountProfileStore {

    // MARK: - Properties

    static let shared = AccountProfileStore()
    private init() {}

    enum LoadError: Error {
        case notSignedIn
        ///Firebase ends the session once a new email is confirmed, so the cached account
        ///still has the old one. The user signs in again, with the new email.
        case sessionEnded
        case failed(Error)
    }

    private func document(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }

    ///An email-and-password account. An Apple account has no password, so its email cannot be
    ///changed here and it has no password to change.
    var hasPasswordAccount: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == EmailAuthProviderID } ?? false
    }

    // MARK: - Loading

    ///The signed-in account, reloaded first so a confirmed email change is seen. The email is
    ///the account's, not the document's: the document has none on some accounts, and keeps
    ///the old one after a change until it is written here, once.
    func load(completion: @escaping (Result<Profile, LoadError>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(.notSignedIn))
            return
        }
        user.reload { [weak self] error in
            guard let self else { return }
            if let error = error as NSError?,
               [AuthErrorCode.userTokenExpired.rawValue, AuthErrorCode.invalidUserToken.rawValue].contains(error.code) {
                completion(.failure(.sessionEnded))
                return
            }
            let user = Auth.auth().currentUser ?? user
            let document = self.document(user.uid)
            document.getDocument { snapshot, error in
                if let error = error as NSError? {
                    print("Loading the account failed: \(error.localizedDescription)")
                    completion(.failure(.failed(error)))
                    return
                }
                let data = snapshot?.data() ?? [:]
                let email = user.email ?? data["email"] as? String ?? ""
                if let stored = data["email"] as? String, !email.isEmpty, stored != email {
                    document.setData(["email": email, "pendingEmail": FieldValue.delete()], merge: true)
                }
                completion(.success(Profile(name: data["name"] as? String ?? "",
                                            email: email,
                                            phoneNumber: data["phoneNumber"] as? String ?? "")))
            }
        }
    }

    // MARK: - Saving

    ///One field of `users/{uid}`, merged, so a missing document does not fail the save.
    func save(_ fields: [String: Any], completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(LoadError.notSignedIn)
            return
        }
        document(uid).setData(fields, merge: true) { error in
            if let error = error as NSError? {
                print("Saving the account failed: \(error.localizedDescription)")
            }
            completion(error)
        }
    }

    ///Confirms with the password, then sends the link to the new address. The email changes
    ///when the link is opened, which also ends this session.
    func changeEmail(to newEmail: String, password: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser, let currentEmail = user.email else {
            completion(LoadError.notSignedIn)
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
        user.reauthenticate(with: credential) { [weak self] _, error in
            if let error = error as NSError? {
                print("Confirming the password failed: \(error.localizedDescription)")
                completion(error)
                return
            }
            user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                if let error = error as NSError? {
                    print("Sending the email change link failed: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                self?.save(["pendingEmail": newEmail]) { _ in completion(nil) }
            }
        }
    }
}
