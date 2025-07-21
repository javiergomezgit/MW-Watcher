//
//  SignUpViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/13/25.
//

import UIKit
import FirebaseAuth
import FirebaseCore

class SignUpViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var verifyTextField: UITextField!
    @IBOutlet weak var appleButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signUpButton.isEnabled = !emailTextField.text!.isEmpty && !passwordTextField.text!.isEmpty && !verifyTextField.text!.isEmpty
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        verifyTextField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
    }
    
    @objc override func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func emailTextFieldChanged(_ sender: UITextField) {
        activateSignUpButton()
        
    }
    
    @IBAction func passwordTextFieldChanged(_ sender: UITextField) {
        activateSignUpButton()
    }
    
    
    @IBAction func verifyTextFieldChanged(_ sender: UITextField) {
        activateSignUpButton()
    }
    
    func activateSignUpButton() {
        if emailTextField.text!.isEmpty || passwordTextField.text!.isEmpty || verifyTextField.text!.isEmpty {
            signUpButton.isEnabled = false
        } else {
            signUpButton.isEnabled = true
        }
    }
    
    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        print("sign up with firebase authentication")
        
        if !verifyFields() {
            return
        } else {
            let email = emailTextField.text!
            let password = passwordTextField.text!
            print ("creating account")
            createAccount(email: email, password: password)
        }
    }
    
    
    func verifyFields() -> Bool {
        if !Utilities.isValidEmail(emailTextField.text!) {
            Utilities.showAlert(on: self, title: "Error", message: "Invalid email format")
            return false
        }  else if passwordTextField.text!.count < 6 {
            Utilities.showAlert(on: self, title: "Error", message: "Password must be at least 6 characters long")
            return false
        } else if passwordTextField.text! != verifyTextField.text! {
            print ("Passwords do not match")
            Utilities.showAlert(on: self, title: "Error", message: "Passwords do not match")
            return false
        } else if emailTextField.text!.isEmpty || passwordTextField.text!.isEmpty || verifyTextField.text!.isEmpty {
            Utilities.showAlert(on: self, title: "Error", message: "Please fill in all fields")
            return false
        }
        
        return true
    }
    
    func createAccount(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Error creating user: \(error.localizedDescription)")
                // Handle error, e.g., show an alert to the user
                Utilities.showAlert(on: self, title: "Error", message: error.localizedDescription)
                return
            }
            // User created successfully!
            print("User signed up: \(authResult?.user.email ?? "N/A")")
            
            let token = authResult!.user.uid
//            UserDefaults.standard.set(token, forKey: "authToken")
            if KeychainManager.saveUID(token) {
                print ("Saved UID to Keychain")
            } else {
                print ("Failed to save UID to Keychain")
            }
            
            // You can now navigate the user to the main part of your app
            self.navigateToMainInterface()
        }
    }
    
    func navigateToMainInterface() {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Change to your actual VC ID
        let mainVC = mainStoryboard.instantiateViewController(withIdentifier: "MarketWatcher")
        
        mainVC.modalPresentationStyle = .fullScreen
        mainVC.modalTransitionStyle = .crossDissolve
        
        self.present(mainVC, animated: true, completion: nil)
    }
    
    @IBAction func appleButtonTapped(_ sender: UIButton) {
        // Call Apple authentication
        print("call apple sign in/up")
        //AppleAuthManager.shared.handleAppleIDRequest() // Calls the @objc method, no closure
        
        AppleAuthManager.shared.signInWithApple { [weak self] result in
            switch result {
            case .success(let resultToken):
                
                let token = resultToken.user.uid
    //            UserDefaults.standard.set(token, forKey: "authToken")
                if KeychainManager.saveUID(token) {
                    print ("Saved UID to Keychain")
                } else {
                    print ("Failed to save UID to Keychain")
                }
                
                print("✅ Apple sign-in successful")
                self?.navigateToMainInterface()
            case .failure(let error):
                print("❌ Apple sign-in failed: \(error.localizedDescription)")
                // Optional: Show alert
            }
        }
    }
    
    @IBAction func signInButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let signInVC = storyboard.instantiateViewController(withIdentifier: "SignInViewController")
        
        signInVC.modalPresentationStyle = .fullScreen
        signInVC.modalTransitionStyle = .crossDissolve
        present(signInVC, animated: true, completion: nil)
    }
}


extension SignUpViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
