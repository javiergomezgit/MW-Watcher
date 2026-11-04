//
//  SignInViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/9/25.
//

import UIKit
import FirebaseAuth

class SignInViewController: UIViewController {
    
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var appleButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var footerLabel: UILabel!
    @IBOutlet weak var footerButton: UIButton!
    
    ///There was no way back into an account whose password was forgotten. (BS-256)
    private let forgotPasswordButton = UIButton(configuration: .plain())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        applyStyle()
        installForgotPassword()
    }
    
    private func applyStyle() {
        AuthStyle.style(emailTextField, placeholder: "Email")
        AuthStyle.style(passwordTextField, placeholder: "Password")
        AuthStyle.stylePrimary(signInButton, title: "Sign In")
        AuthStyle.styleApple(appleButton)
        AuthStyle.styleSkip(skipButton)
        AuthStyle.styleFooter(label: footerLabel, text: "Don't have an account?", button: footerButton, title: "Sign Up")
    }
    
    ///Under the password field, trailing, in the 50 pt gap above the Sign In button.
    private func installForgotPassword() {
        forgotPasswordButton.configuration?.title = "Forgot password?"
        forgotPasswordButton.configuration?.baseForegroundColor = ProfileStyle.secondaryText
        forgotPasswordButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        forgotPasswordButton.addAction(UIAction { [weak self] _ in self?.forgotPasswordTapped() }, for: .touchUpInside)
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(forgotPasswordButton)
        NSLayoutConstraint.activate([
            forgotPasswordButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 6),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: passwordTextField.trailingAnchor)
        ])
    }
    
    ///Asks for the address, filled in from the email field. Firebase does not say whether an
    ///account exists for it, so neither does the message.
    private func forgotPasswordTapped() {
        let alert = UIAlertController(title: "Reset Password",
                                      message: "We'll email you a link to set a new password.",
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.placeholder = "Email"
            field.text = self?.emailTextField.text
            field.keyboardType = .emailAddress
            field.textContentType = .emailAddress
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Link", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let email = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard email.contains("@") else {
                Utilities.showAlert(on: self, title: "Missing Information", message: "Please enter your email address.")
                return
            }
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                DispatchQueue.main.async {
                    if let error = error as NSError? {
                        print("Sending the password reset email failed: \(error.localizedDescription)")
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                        return
                    }
                    Utilities.showAlert(on: self, title: "Check Your Email",
                                        message: "If there's an account for \(email), a link to reset its password is on its way.")
                }
            }
        })
        present(alert, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //        let gradient = CAGradientLayer()
        //        gradient.frame = view.bounds
        //        gradient.colors = [UIColor.systemGreen.cgColor, UIColor.systemGray.cgColor]
        //        view.layer.insertSublayer(gradient, at: 0)
        
        signInButton.isEnabled = !emailTextField.text!.isEmpty && !passwordTextField.text!.isEmpty
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
    }
    
    @objc override func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func passwordTextFieldChanged(_ sender: UITextField) {
        activateSignInButton()
    }
    
    @IBAction func emailTextFieldChanged(_ sender: UITextField) {
        activateSignInButton()
    }
    
    func activateSignInButton() {
        if emailTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            signInButton.isEnabled = false
        } else {
            signInButton.isEnabled = true
        }
    }
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "userPrefersNoAccount")
        navigateToMainInterface()
    }
    
    @IBAction func signInButtonTapped(_ sender: UIButton) {
        print("Attempting sign-in with email and Firebase Authentication")

        guard let email = emailTextField.text, let password = passwordTextField.text, !email.isEmpty, !password.isEmpty else {
            print("Email or password is empty")
            Utilities.showAlert(on: self, title: "Missing Information", message: "Please enter both email and password.")
            return
        }

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }

            if let error = error as NSError? {
                print("❌ Email sign-in failed: Code=\(error.code), Domain=\(error.domain), Details=\(error.userInfo)")

                // Ensure error is in FIRAuthErrorDomain
                guard error.domain == AuthErrorDomain else {
                    Utilities.showAlert(on: self, title: "Sign-In Error", message: "An unexpected error occurred. Please try again.")
                    print("Non-Firebase error: \(error.localizedDescription)")
                    return
                }
                // Map Firebase error codes to user-friendly messages
                let errorMessage: String
                switch error.code {
                case AuthErrorCode.invalidEmail.rawValue: // 17008
                    errorMessage = "The email address is invalid. Please check and try again."
                case AuthErrorCode.userNotFound.rawValue: // 17011
                    errorMessage = "This account does not exist. Please sign up or try a different account."
                case AuthErrorCode.wrongPassword.rawValue: // 17009
                    errorMessage = "The password is incorrect. Please try again."
                case AuthErrorCode.invalidCredential.rawValue: // 17004
                    errorMessage = "Your login credentials are invalid or have expired. Please try again."
                case AuthErrorCode.userDisabled.rawValue: // 17009
                    errorMessage = "This account has been disabled. Please contact support."
                case AuthErrorCode.networkError.rawValue: // 17020
                    errorMessage = "Network error. Please check your internet connection and try again."
                case AuthErrorCode.userTokenExpired.rawValue, AuthErrorCode.invalidUserToken.rawValue: // 17012, 17005
                    errorMessage = "Your session has expired. Please sign in again."
                default:
                    errorMessage = "An error occurred while signing in. Please try again."
                    print("Unexpected auth error: Code=\(error.code), Domain=\(error.domain), Details=\(error.userInfo)")
                }

                Utilities.showAlert(on: self, title: "Sign-In Error", message: errorMessage)
                return
            }

            guard let user = result?.user else {
                print("❌ No user returned after sign-in")
                Utilities.showAlert(on: self, title: "Sign-In Error", message: "Failed to retrieve user information. Please try again.")
                return
            }

            print("✅ Email sign-in successful for user: \(user.uid)")
            if KeychainManager.saveUID(user.uid) {
                print("Saved UID to Keychain")
            } else {
                print("Failed to save UID to Keychain")
            }
            UserDefaults.standard.set(false, forKey: "userPrefersNoAccount")
            self.navigateToMainInterface()
        }
    }
    
    
    @IBAction func appleButtonTapped(_ sender: UIButton) {
        // Call Apple authentication
        print("call apple sign in/up")
        
        AppleAuthManager.shared.signInWithApple { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let resultToken):
                print("✅ Apple sign-in successful")
                
                let token = resultToken.user.uid
                //            UserDefaults.standard.set(token, forKey: "authToken")
                if KeychainManager.saveUID(token) {
                    print ("Saved UID to Keychain")
                } else {
                    print ("Failed to save UID to Keychain")
                }
                UserDefaults.standard.set(false, forKey: "userPrefersNoAccount")
                self.navigateToMainInterface()
            case .failure(let error):
                print("❌ Apple sign-in failed: \(error.localizedDescription)")
                Utilities.showAlert(on: self, title: "Error", message: error.localizedDescription)
            }
        }
    }
    
    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let signUpVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")
        
        signUpVC.modalPresentationStyle = .fullScreen
        signUpVC.modalTransitionStyle = .crossDissolve
        present(signUpVC, animated: true, completion: nil)
    }
    
    func navigateToMainInterface() {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Change to your actual VC ID
        let mainVC = mainStoryboard.instantiateViewController(withIdentifier: "MarketWatcher")
        
        mainVC.modalPresentationStyle = .fullScreen
        mainVC.modalTransitionStyle = .crossDissolve
        
        self.present(mainVC, animated: true, completion: nil)
    }
    
    //    func handleLoginSuccess(token: String) {
    //        UserDefaults.standard.set(token, forKey: "authToken")
    //        let storyboard = UIStoryboard(name: "Main", bundle: nil)
    //        let mainTabBar = storyboard.instantiateInitialViewController()!
    //        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
    //            sceneDelegate.window?.rootViewController = mainTabBar
    //        }
    //    }
}


extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
