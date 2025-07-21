//
//  AppleAuthManager.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/13/25.
//

import AuthenticationServices // Needed for Sign In with Apple
import FirebaseAuth // Handles Firebase login
import FirebaseFirestore // Saves user info to Firestore

class AppleAuthManager: NSObject, ASAuthorizationControllerDelegate {
    
    // Singleton: Use AppleAuthManager.shared to access this anywhere
    static let shared = AppleAuthManager()
    
    // Stores the result handler to send login success or error back
    private var completionHandler: ((Result<AuthDataResult, Error>) -> Void)?
    
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
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            self.completionHandler = completion
            authorizationController.performRequests() // Shows Apple’s sign-in popup
        }
    }
    
    // Handles successful sign-in with Apple
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Got Apple’s login data (like a token)
            let nonce = String.randomNonceString() // Random string for secure login
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
                if let authResult = authResult {
                    // Save name and email to Firestore if we got them
                    if let fullName = appleIDCredential.fullName {
                        let db = Firestore.firestore()
                        let userData: [String: Any] = [
                            "givenName": fullName.givenName ?? "",
                            "familyName": fullName.familyName ?? "",
                            "email": appleIDCredential.email ?? authResult.user.email ?? ""
                        ]
                        // Save to Firestore under the user’s ID
                        db.collection("users").document(authResult.user.uid).setData(userData, merge: true) { error in
                            if let error = error {
                                print("Failed to save user data: \(error.localizedDescription)")
                            }
                        }
                    }
                    print("Signed in with Apple: \(authResult.user.email ?? "No email")")
                    self.completionHandler?(.success(authResult))
                }
            }
        }
    }
    
    // Handles errors, like if the user cancels sign-in
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign-in failed: \(error.localizedDescription)")
        completionHandler?(.failure(error))
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    // Picks the window to show the Apple sign-in popup
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found for sign-in popup")
        }
        return window
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
