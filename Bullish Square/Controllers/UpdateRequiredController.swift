//
//  UpdateRequiredController.swift
//  Bullish Square
//

import UIKit

///The screen AppUpdateGate puts over the app when this version is no longer supported. It has
///no way out but the App Store. (BS-233)
final class UpdateRequiredController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ProfileStyle.background

        let logo = UIImageView(image: UIImage(named: "BS-Logo-WhiteB"))
        logo.contentMode = .scaleAspectFit
        logo.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Update Required"
        titleLabel.font = UIFont(name: "Avenir-Heavy", size: 26) ?? .systemFont(ofSize: 26, weight: .heavy)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "This version of Bullish Square is no longer supported. Update to the latest version to keep using the app."
        messageLabel.font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = ProfileStyle.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let updateButton = UIButton(configuration: .filled())
        AuthStyle.stylePrimary(updateButton, title: "Update")
        updateButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        updateButton.addAction(UIAction { _ in
            UIApplication.shared.open(AppUpdateGate.appStoreURL)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logo, titleLabel, messageLabel, updateButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(32, after: logo)
        stack.setCustomSpacing(32, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -16)
        ])
    }
}
