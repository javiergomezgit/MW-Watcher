//
//  AccountDeletionManager.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/11/26.
//

import AuthenticationServices
import CoreData
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import UIKit

///Deletes the signed-in account and everything this device holds for it.
///
///App Review guideline 5.1.1(v) requires any app that creates accounts to offer deletion
///from inside the app, so this is the whole path: re-authenticate, remove the Firestore
///document, delete the Firebase user, then wipe local storage.
final class AccountDeletionManager: NSObject {

    static let shared = AccountDeletionManager()

    private override init() { super.init() }

    enum DeletionError: LocalizedError {
        case notSignedIn
        case unsupportedProvider(String)
        case missingEmail
        case appleTokenUnavailable
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You are not signed in."
            case .unsupportedProvider(let provider):
                return "Accounts created with \(provider) cannot be deleted from here yet."
            case .missingEmail:
                return "This account has no email address on file, so your password cannot be confirmed."
            case .appleTokenUnavailable:
                return "Apple did not return a usable identity token."
            case .cancelled:
                return "Cancelled."
            }
        }
    }

    //Held between starting the Apple request and its delegate callback.
    private var appleReauthCompletion: ((Result<(AuthCredential, String?), Error>) -> Void)?
    private var currentNonce: String?
    private weak var presentationAnchorProvider: UIViewController?
    private var isDeleting = false

    // MARK: - Entry point

    ///Order matters. The Firestore document goes first, while the user is still
    ///authenticated, because security rules key on request.auth.uid and the write would be
    ///refused once the auth user is gone. Local data goes last, so a failure part-way
    ///through leaves the device still able to sign in and retry.
    func deleteAccount(presentingOn presenter: UIViewController,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(DeletionError.notSignedIn))
            return
        }

        //One at a time. A second run would overwrite the pending Apple completion and the
        //first caller would never hear back.
        guard !isDeleting else { return }
        isDeleting = true

        let uid = user.uid

        //Strong self throughout: this is a singleton, and a weak capture that failed would
        //drop the completion and leave the caller waiting forever.
        let finish: (Result<Void, Error>) -> Void = { [self] result in
            isDeleting = false
            completion(result)
        }

        reauthenticate(user: user, presentingOn: presenter) { result in
            switch result {
            case .failure(let error):
                finish(.failure(error))

            case .success(let appleAuthorizationCode):
                Firestore.firestore().collection("users").document(uid).delete { firestoreError in
                    if let firestoreError {
                        //Not fatal on its own, but the account must not be deleted while its
                        //document survives: that would orphan the data with no way back in.
                        finish(.failure(firestoreError))
                        return
                    }

                    //Apple requires apps using Sign in with Apple to revoke the token on
                    //deletion, not merely drop the Firebase user.
                    self.revokeAppleTokenIfNeeded(authorizationCode: appleAuthorizationCode) {
                        user.delete { deleteError in
                            if let deleteError {
                                finish(.failure(deleteError))
                                return
                            }

                            self.clearLocalData()
                            finish(.success(()))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Re-authentication

    ///Firebase refuses to delete a user whose sign-in is not recent, so this always runs.
    ///Returns the Apple authorization code when the account is an Apple one, since revoking
    ///the token later needs it.
    private func reauthenticate(user: User,
                                presentingOn presenter: UIViewController,
                                completion: @escaping (Result<String?, Error>) -> Void) {
        let providers = user.providerData.map { $0.providerID }

        if providers.contains("apple.com") {
            reauthenticateWithApple(presentingOn: presenter) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let (credential, authorizationCode)):
                    user.reauthenticate(with: credential) { _, error in
                        if let error {
                            completion(.failure(error))
                        } else {
                            completion(.success(authorizationCode))
                        }
                    }
                }
            }
            return
        }

        if providers.contains("password") {
            guard let email = user.email else {
                completion(.failure(DeletionError.missingEmail))
                return
            }

            promptForPassword(presentingOn: presenter) { password in
                guard let password else {
                    completion(.failure(DeletionError.cancelled))
                    return
                }

                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                user.reauthenticate(with: credential) { _, error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(nil))
                    }
                }
            }
            return
        }

        completion(.failure(DeletionError.unsupportedProvider(providers.first ?? "an unknown provider")))
    }

    private func promptForPassword(presentingOn presenter: UIViewController,
                                   completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Confirm Your Password",
                message: "Enter your password to permanently delete this account.",
                preferredStyle: .alert
            )

            alert.addTextField { textField in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            }

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion(nil)
            })

            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak alert] _ in
                guard let password = alert?.textFields?.first?.text, !password.isEmpty else {
                    completion(nil)
                    return
                }
                completion(password)
            })

            presenter.present(alert, animated: true)
        }
    }

    ///A fresh Sign in with Apple round trip. The nonce is generated first, sent hashed on
    ///the request, and handed to Firebase raw, so Firebase can match it against the claim
    ///inside the returned identity token.
    private func reauthenticateWithApple(presentingOn presenter: UIViewController,
                                         completion: @escaping (Result<(AuthCredential, String?), Error>) -> Void) {
        DispatchQueue.main.async {
            let nonce = Self.randomNonceString()
            self.currentNonce = nonce
            self.presentationAnchorProvider = presenter
            self.appleReauthCompletion = completion

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func revokeAppleTokenIfNeeded(authorizationCode: String?, completion: @escaping () -> Void) {
        guard let authorizationCode else {
            completion()
            return
        }

        Auth.auth().revokeToken(withAuthorizationCode: authorizationCode) { error in
            if let error {
                //Deletion still goes ahead. Apple's requirement is that the app asks; a
                //refusal here should not strand the user with an account they cannot remove.
                print("Could not revoke Apple token: \(error.localizedDescription)")
            }
            completion()
        }
    }

    // MARK: - Local cleanup

    ///Everything on this device. Core Data holds no per-account key, so any row left behind
    ///would surface under whoever signs in next.
    private func clearLocalData() {
        DispatchQueue.main.async {
            if !KeychainManager.deleteUID() {
                print("No UID found in Keychain to remove")
            }

            UserDefaults.standard.removeObject(forKey: "authToken")

            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let managedContext = appDelegate.persistentContainer.viewContext

            for entityName in ["WatchlistEntity", "SavedNewsEntity", "ProfileEntity", "LiveNewsEntity"] {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                do {
                    try managedContext.execute(deleteRequest)
                } catch let error as NSError {
                    print("Could not clear \(entityName). \(error), \(error.userInfo)")
                }
            }

            do {
                try managedContext.save()
            } catch let error as NSError {
                print("Could not save after clearing local data. \(error), \(error.userInfo)")
            }

            //A batch delete goes straight to the store, so the context still holds the old
            //objects until it is told to drop them.
            managedContext.reset()
        }
    }

    // MARK: - Nonce

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            //Falling back to UUIDs keeps deletion reachable. It is less entropy than
            //SecRandomCopyBytes, but this nonce only has to be unique per request.
            return UUID().uuidString + UUID().uuidString
        }

        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AccountDeletionManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        let completion = appleReauthCompletion
        appleReauthCompletion = nil

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            completion?(.failure(DeletionError.appleTokenUnavailable))
            return
        }

        currentNonce = nil

        let credential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                  idToken: idTokenString,
                                                  rawNonce: nonce)

        let authorizationCode = appleIDCredential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        completion?(.success((credential, authorizationCode)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let completion = appleReauthCompletion
        appleReauthCompletion = nil
        currentNonce = nil

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            completion?(.failure(DeletionError.cancelled))
        } else {
            completion?(.failure(error))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AccountDeletionManager: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        //Never fatalError here the way the sign-in path does. Failing to delete an account
        //must not take the app down with it.
        if let window = presentationAnchorProvider?.view.window {
            return window
        }

        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first ?? UIWindow()
    }
}
