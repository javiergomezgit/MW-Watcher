//
//  AuthStyle.swift
//  Bullish Square
//

import UIKit

///Sign In and Sign Up, drawn from the brand palette in ProfileStyle. The storyboard gave
///them black square fields, a grey disabled button with black text, an Apple button that
///was a picture with its own larger lettering, and Helvetica beside the app's Avenir.
enum AuthStyle {

    // MARK: - Metrics

    static let cornerRadius: CGFloat = 14
    static let navy = ProfileStyle.background

    private static func avenir(_ name: String, _ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Fields

    static func style(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = avenir("Avenir-Medium", 17, .medium)
        ProfileStyle.style(field)
        field.layer.cornerRadius = cornerRadius
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
    }

    // MARK: - Buttons

    ///Pale teal with navy lettering. Disabled, it fades rather than turning system grey.
    static func stylePrimary(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        button.configuration = config
        button.configurationUpdateHandler = { button in
            guard var config = button.configuration else { return }
            let alpha: CGFloat = button.isEnabled ? 1 : 0.35
            config.background.backgroundColor = ProfileStyle.text.withAlphaComponent(alpha)
            let foreground = navy.withAlphaComponent(button.isEnabled ? 1 : 0.7)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = avenir("Avenir-Heavy", 18, .heavy)
                attributes.foregroundColor = foreground
                return attributes
            }
            button.configuration = config
        }
        button.setNeedsUpdateConfiguration()
    }

    ///White with the Apple logo and San Francisco, as Apple's guidelines ask of a custom
    ///Sign in with Apple button, and the same size and corners as the button above it.
    static func styleApple(_ button: UIButton) {
        var config = UIButton.Configuration.filled()
        config.title = "Continue with Apple"
        config.image = UIImage(systemName: "apple.logo",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        config.imagePadding = 8
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 18, weight: .semibold)
            return attributes
        }
        button.configuration = config
        button.configurationUpdateHandler = nil
    }

    static func styleSkip(_ button: UIButton) {
        styleLink(button, title: "Skip", font: avenir("Avenir-Medium", 16, .medium), color: ProfileStyle.secondaryText)
    }

    ///"Don't have an account?  Sign Up" along the bottom.
    static func styleFooter(label: UILabel, text: String, button: UIButton, title: String) {
        label.text = text
        label.font = avenir("Avenir-Medium", 16, .medium)
        label.textColor = ProfileStyle.secondaryText
        styleLink(button, title: title, font: avenir("Avenir-Heavy", 16, .heavy), color: ProfileStyle.text)
    }

    private static func styleLink(_ button: UIButton, title: String, font: UIFont, color: UIColor) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        button.configuration = config
    }
}
