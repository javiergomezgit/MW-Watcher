//
//  FieldEditController.swift
//  Bullish Square
//

import UIKit

///One field of the profile on a screen of its own, as Personal Information opens it: the
///value, a note under it, Save. The caller decides what saving means, and answers with an
///error message or nil. (BS-260)
final class FieldEditController: UIViewController, UITextFieldDelegate {

    // MARK: - Properties

    struct Field {
        var title: String
        var value: String
        var placeholder: String
        var note: String?
        var keyboard: UIKeyboardType = .default
        var contentType: UITextContentType?
        var capitalization: UITextAutocapitalizationType = .sentences
        ///Prefixed in front of the value, as "@" is for the username.
        var prefix: String?
    }

    ///Text as typed; calls back with nil when it saved, the message to show, or "" to stay
    ///on the screen without one (a prompt the user cancelled).
    var onSave: ((String, @escaping (String?) -> Void) -> Void)?

    private let field: Field
    private let textField = UITextField()
    private let noteLabel = UILabel()

    init(field: Field) {
        self.field = field
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = field.title
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = ProfileStyle.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))

        textField.text = field.value
        textField.placeholder = field.placeholder
        textField.keyboardType = field.keyboard
        textField.textContentType = field.contentType
        textField.autocapitalizationType = field.capitalization
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if let prefix = field.prefix {
            let label = UILabel()
            label.text = "   \(prefix)"
            label.textColor = ProfileStyle.secondaryText
            label.sizeToFit()
            textField.leftView = label
            textField.leftViewMode = .always
        }

        ProfileStyle.style(textField)

        noteLabel.text = field.note
        noteLabel.numberOfLines = 0
        noteLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13)
        noteLabel.textColor = ProfileStyle.secondaryText

        let stack = UIStackView(arrangedSubviews: [textField, noteLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return false
    }

    // MARK: - Saving

    @objc private func saveTapped() {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != field.value else {
            navigationController?.popViewController(animated: true)
            return
        }
        guard let onSave else { return }
        setSaving(true)
        onSave(text) { [weak self] problem in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setSaving(false)
                if let problem, problem.isEmpty {
                    return
                } else if let problem {
                    Utilities.showAlert(on: self, title: "Can't Save", message: problem)
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }

    private func setSaving(_ saving: Bool) {
        textField.isEnabled = !saving
        navigationItem.rightBarButtonItem?.isEnabled = !saving
    }
}
