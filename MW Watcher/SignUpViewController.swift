//
//  SignUpViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 7/13/25.
//

import UIKit

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
    
    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        print("sign up with firebase authentication")
    }
    
    @IBAction func appleButtonTappe(_ sender: UIButton) {
        print ("sign up with apple authentication")
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
