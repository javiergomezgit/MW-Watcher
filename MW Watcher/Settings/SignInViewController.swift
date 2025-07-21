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
    
    
    @IBAction func signInButtonTapped(_ sender: UIButton) {
        sender.layer.cornerRadius = 8
        sender.clipsToBounds = true
        // For gradient, use CAGradientLayer as sublayer of button
        print ("sign in with email into with firebase authentication")
        
        guard let email = emailTextField.text, let password = passwordTextField.text, !email.isEmpty, !password.isEmpty else {
            // Show an alert if fields are empty
            print("Email or password is empty")
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("❌ Email sign-in failed: \(error.localizedDescription)")
                // Optional: Show alert to user
                Utilities.showAlert(on: self!, title: "Error", message: error.localizedDescription)
                return
            }
            
            print("✅ Email sign-in successful")
            let token = result?.user.uid
            UserDefaults.standard.set(token, forKey: "authToken")
            self?.navigateToMainInterface()
        }
    }
    
    @IBAction func appleButtonTapped(_ sender: UIButton) {
        // Call Apple authentication
        print("call apple sign in/up")
        
        AppleAuthManager.shared.signInWithApple { [weak self] result in
            switch result {
            case .success(let resultToken):
                print("✅ Apple sign-in successful")
                let token = resultToken.user.uid
                UserDefaults.standard.set(token, forKey: "authToken")
                self?.navigateToMainInterface()
            case .failure(let error):
                print("❌ Apple sign-in failed: \(error.localizedDescription)")
                Utilities.showAlert(on: self!, title: "Error", message: error.localizedDescription)
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
