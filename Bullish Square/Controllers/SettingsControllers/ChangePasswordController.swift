//
//  ChangePasswordController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth

///Settings > Password and Security. The current password confirms the change, since Firebase
///needs a recent sign-in to set a new one. An Apple account has no password to change and is
///told so. Replaces the storyboard's SecuritySettingsController, whose row did nothing and
///whose scene had an outlet the class did not declare, so it could not have opened. (BS-256)
final class ChangePasswordController: UIViewController {

    // MARK: - Properties

    ///Firebase accepts six; eight is the floor most password guidance asks for.
    static let minimumLength = 8

    private let currentField = ChangePasswordController.makeField(placeholder: "Current password", contentType: .password)
    private let newField = ChangePasswordController.makeField(placeholder: "New password", contentType: .newPassword)
    private let confirmField = ChangePasswordController.makeField(placeholder: "Confirm new password", contentType: .newPassword)
    private let updateButton = UIButton(configuration: .filled())
    private let resetButton = UIButton(configuration: .plain())
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var hasPasswordAccount: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == EmailAuthProviderID } ?? false
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Password"
        view.backgroundColor = ProfileStyle.background
        ProfileStyle.style(navigationController)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        hasPasswordAccount ? buildPasswordForm() : buildManagedByApple()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Layout

    private static func makeField(placeholder: String, contentType: UITextContentType) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.isSecureTextEntry = true
        field.textContentType = contentType
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        ProfileStyle.style(field)
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }

    private func buildPasswordForm() {
        messageLabel.text = "At least \(Self.minimumLength) characters."
        styleMessage()

        updateButton.configuration?.title = "Update Password"
        updateButton.configuration?.cornerStyle = .medium
        updateButton.configuration?.baseBackgroundColor = ProfileStyle.accent
        updateButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        updateButton.addAction(UIAction { [weak self] _ in self?.updateTapped() }, for: .touchUpInside)

        resetButton.configuration?.title = "Forgot your password?"
        resetButton.configuration?.baseForegroundColor = ProfileStyle.accent
        resetButton.addAction(UIAction { [weak self] _ in self?.sendResetEmail() }, for: .touchUpInside)

        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [currentField, newField, confirmField, messageLabel,
                                                   updateButton, spinner, resetButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: messageLabel)
        install(stack)
        currentField.becomeFirstResponder()
    }

    private func buildManagedByApple() {
        messageLabel.text = "You sign in with Apple, so there is no Bullish Square password to change. Your Apple ID's password and security are managed in the Settings app."
        styleMessage()
        install(UIStackView(arrangedSubviews: [messageLabel]))
    }

    private func styleMessage() {
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont(name: "Avenir-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = ProfileStyle.secondaryText
    }

    private func install(_ stack: UIStackView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    // MARK: - Actions

    private func updateTapped() {
        view.endEditing(true)
        let current = currentField.text ?? ""
        let new = newField.text ?? ""
        guard !current.isEmpty else { return showProblem("Enter your current password.") }
        guard new.count >= Self.minimumLength else {
            return showProblem("The new password needs at least \(Self.minimumLength) characters.")
        }
        guard new == confirmField.text else { return showProblem("The new passwords don't match.") }
        guard new != current else { return showProblem("The new password is the same as the current one.") }
        guard let user = Auth.auth().currentUser, let email = user.email else { return }

        setBusy(true)
        let credential = EmailAuthProvider.credential(withEmail: email, password: current)
        user.reauthenticate(with: credential) { [weak self] _, error in
            if let error = error as NSError? {
                print("Confirming the current password failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.finish(with: error) }
                return
            }
            user.updatePassword(to: new) { error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error = error as NSError? {
                        print("Updating the password failed: \(error.localizedDescription)")
                        self.finish(with: error)
                        return
                    }
                    self.setBusy(false)
                    Utilities.showAlertWithCompletion(on: self, title: "Password Updated",
                                                      message: "Use your new password the next time you sign in.") {
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }

    private func sendResetEmail() {
        guard let email = Auth.auth().currentUser?.email else { return }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error as NSError? {
                    print("Sending the password reset email failed: \(error.localizedDescription)")
                    Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                    return
                }
                Utilities.showAlert(on: self, title: "Check Your Email",
                                    message: "We sent a link to \(email) to set a new password.")
            }
        }
    }

    // MARK: - State

    private func setBusy(_ busy: Bool) {
        updateButton.isEnabled = !busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private func finish(with error: NSError) {
        setBusy(false)
        switch error.code {
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.invalidCredential.rawValue:
            showProblem("Your current password is incorrect.")
        case AuthErrorCode.weakPassword.rawValue:
            showProblem("That password is too weak. Try a longer one.")
        case AuthErrorCode.tooManyRequests.rawValue:
            showProblem("Too many attempts. Wait a few minutes and try again.")
        default:
            Utilities.showErrorAlert(on: self, message: error.localizedDescription)
        }
    }

    private func showProblem(_ message: String) {
        Utilities.showAlert(on: self, title: "Can't Update Password", message: message)
    }
}
