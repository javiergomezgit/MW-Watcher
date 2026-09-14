//
//  AppleAuthManager.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/13/25.
//

import AuthenticationServices // Needed for Sign In with Apple
import CryptoKit // Hashes the sign-in nonce
import FirebaseAuth // Handles Firebase login
import FirebaseFirestore // Saves user info to Firestore

class AppleAuthManager: NSObject, ASAuthorizationControllerDelegate {
    
    // Singleton: Use AppleAuthManager.shared to access this anywhere
    static let shared = AppleAuthManager()
    
    // Stores the result handler to send login success or error back
    private var completionHandler: ((Result<AuthDataResult, Error>) -> Void)?

    // The raw nonce for the request in flight. Apple returns its SHA256 inside the identity
    // token, and Firebase compares the two, so it has to survive until the callback.
    private var currentNonce: String?
    
    // Creates the Sign In with Apple button for your login screen
    // Returns the button so you can add it to your UI
    func setupAppleSignInButton() -> ASAuthorizationAppleIDButton {
        let appleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: .black)
        appleButton.addTarget(self, action: #selector(handleAppleIDRequest), for: .touchUpInside)
        return appleButton // Add this to your view in a UIViewController
    }
    
    // Called when the Apple Sign In button is tapped
    @objc func handleAppleIDRequest() {
        // Starts the sign-in process (no result handling needed here)
        signInWithApple { _ in }
    }
    
    // Starts Sign In with Apple and lets you handle success or error
    func signInWithApple(completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        DispatchQueue.main.async { // Runs on main thread to keep UI smooth
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email] // Asks for name and email, shows "Hide My Email" option

            // Generate the nonce here, before the request, and send its hash. This used to be
            // built inside the callback instead and never put on the request at all, so the
            // identity token came back with no nonce claim and a brand new random string was
            // handed to Firebase as the raw nonce. Without it a captured token can be replayed.
            let nonce = String.randomNonceString()
            self.currentNonce = nonce
            request.nonce = Self.sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            self.completionHandler = completion
            authorizationController.performRequests() // Shows Apple’s sign-in popup
        }
    }
    
    // Handles successful sign-in with Apple
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        // Anything other than an Apple ID credential used to fall straight through this
        // method without calling the completion, leaving the button doing nothing at all.
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completionHandler?(.failure(NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unexpected credential type from Apple"])))
            return
        }

        guard let nonce = currentNonce else {
            completionHandler?(.failure(NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing sign-in nonce"])))
            return
        }
        currentNonce = nil

        guard let appleIDToken = appleIDCredential.identityToken else {
            print("No Apple ID token found")
            completionHandler?(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID token"])))
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Couldn’t convert token to string: \(appleIDToken.debugDescription)")
            completionHandler?(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize token"])))
            return
        }
        
        // Use Apple’s token to log in with Firebase
        let firebaseCredential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                          idToken: idTokenString,
                                                          rawNonce: nonce)
        
        // Log in to Firebase
        Auth.auth().signIn(with: firebaseCredential) { (authResult, error) in
            if let error = error {
                print("Apple login failed: \(error.localizedDescription)")
                self.completionHandler?(.failure(error))
                return
            }
            // Neither branch used to fire when authResult and error were both nil, which
            // left the caller with no success, no error, and nothing on screen.
            guard let authResult else {
                self.completionHandler?(.failure(NSError(domain: "", code: -5, userInfo: [NSLocalizedDescriptionKey: "Firebase returned no result for the Apple sign-in"])))
                return
            }

            // Save name and email to Firestore if we got them
            if let fullName = appleIDCredential.fullName,
               authResult.additionalUserInfo?.isNewUser == true {
                //First time this Apple ID signs into Firebase
                var name = "\(fullName.givenName ?? "")_\(fullName.familyName ?? "")"
                if name == "" {
                    let tempName = appleIDCredential.email?.split(separator: "@") ?? authResult.user.email?.split(separator: "@") ?? ["Without Name"]
                    name = String(tempName[0])
                }
                let userData: [String: Any] = [
                    "name": name,
                    "email": appleIDCredential.email ?? authResult.user.email ?? ""
                ]
                // Save to Firestore under the user’s ID
                Firestore.firestore().collection("users").document(authResult.user.uid).setData(userData, merge: true) { error in
                    if let error = error {
                        print("Failed to save user data: \(error.localizedDescription)")
                    }
                }
            }

            print("Signed in with Apple: \(authResult.user.email ?? "No email")")
            self.completionHandler?(.success(authResult))
        }
    }
    
    // Handles errors, like if the user cancels sign-in
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign-in failed: \(error.localizedDescription)")
        currentNonce = nil
        completionHandler?(.failure(error))
    }

    // Apple hashes the nonce it receives into the identity token, so the request carries the
    // hash and Firebase gets the raw value to compare against.
    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    // Picks the window to show the Apple sign-in popup
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // This used to fatalError. Failing to find a window is not worth taking the app down
        // for: Apple reports a presentation failure through didCompleteWithError instead.
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first ?? UIWindow()
    }
}

// Generates a random string for secure Apple sign-in
extension String {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Failed to generate random string: OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let result = randomBytes.map { byte -> Character in
            guard Int(byte) < charset.count else {
                return charset[Int(byte) % charset.count]
            }
            return charset[Int(byte)]
        }
        
        return String(result)
    }
}
