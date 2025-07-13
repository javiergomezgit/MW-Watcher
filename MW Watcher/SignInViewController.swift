//
//  SignInViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/9/25.
//

import UIKit

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
        signInButton.isEnabled = !emailTextField.text!.isEmpty && !passwordTextField.text!.isEmpty
    }
    
    @IBAction func emailTextFieldChanged(_ sender: UITextField) {
        signInButton.isEnabled = !emailTextField.text!.isEmpty && !passwordTextField.text!.isEmpty
    }
    
    
    @IBAction func signInButtonTapped(_ sender: UIButton) {
        sender.layer.cornerRadius = 8
        sender.clipsToBounds = true
        // For gradient, use CAGradientLayer as sublayer of button
        print ("sign in with email into with firebase authentication")
    }
    
    @IBAction func appleButtonTapped(_ sender: UIButton) {
        print ("call apple sign in/up")
    }
    
    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let signUpVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")
        
        signUpVC.modalPresentationStyle = .fullScreen
        signUpVC.modalTransitionStyle = .crossDissolve
        present(signUpVC, animated: true, completion: nil)
    }
}


extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
