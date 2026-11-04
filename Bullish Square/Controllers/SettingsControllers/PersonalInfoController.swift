//
//  PersonalInfoController.swift
//  Bullish Square
//

import UIKit

///Profile > Personal Information: one row per detail with its value, each opening its own
///editor, as the system Settings app does. The name and username are public; the email and
///phone stay private. (BS-260)
final class PersonalInfoController: UITableViewController {

    // MARK: - Properties

    private enum Row {
        case name, username, email, phone, password, memberSince
    }

    private let sections: [(title: String?, footer: String?, rows: [Row])] = [
        ("Public", "Shown on your profile to other members.", [.name, .username]),
        ("Private", "Only you can see these.", [.email, .phone]),
        ("Security", nil, [.password]),
        (nil, nil, [.memberSince])
    ]

    var profile: Profile
    ///Each saved change, so the profile screen shows it without a reload.
    var onChange: ((Profile) -> Void)?

    private let accounts = AccountProfileStore.shared

    init(profile: Profile) {
        self.profile = profile
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Personal Information"
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(tableView)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        ProfileStyle.style(headerFooter: view)
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        ProfileStyle.style(headerFooter: view)
    }

    private func changed() {
        tableView.reloadData()
        onChange?(profile)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        cell.accessoryType = .disclosureIndicator
        switch sections[indexPath.section].rows[indexPath.row] {
        case .name:
            content.text = "Name"
            content.secondaryText = profile.name.isEmpty ? "Add" : profile.name
        case .username:
            content.text = "Username"
            content.secondaryText = profile.username.map { "@\($0)" } ?? "Choose"
        case .email:
            content.text = "Email"
            content.secondaryText = profile.email
            if !accounts.hasPasswordAccount { cell.accessoryType = .none }
        case .phone:
            content.text = "Phone"
            content.secondaryText = (profile.phoneNumber ?? "").isEmpty ? "Add" : profile.phoneNumber
        case .password:
            content.text = "Password"
            content.secondaryText = accounts.hasPasswordAccount ? "Change" : "Managed by Apple"
        case .memberSince:
            content.text = "Member since"
            content.secondaryText = profile.memberSince.map { $0.formatted(.dateTime.month(.wide).year()) } ?? "—"
            cell.accessoryType = .none
            cell.selectionStyle = .none
        }
        content.secondaryTextProperties.lineBreakMode = .byTruncatingMiddle
        ProfileStyle.style(&content)
        ProfileStyle.style(cell)
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .name: editName()
        case .username: editUsername()
        case .email: editEmail()
        case .phone: editPhone()
        case .password:
            present(UINavigationController(rootViewController: ChangePasswordController()), animated: true)
        case .memberSince:
            break
        }
    }

    // MARK: - Editors

    private func push(_ field: FieldEditController.Field,
                      save: @escaping (FieldEditController, String, @escaping (String?) -> Void) -> Void) {
        let editor = FieldEditController(field: field)
        editor.onSave = { [weak editor] text, done in
            guard let editor else { return }
            save(editor, text, done)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func editName() {
        push(.init(title: "Name", value: profile.name, placeholder: "Your name",
                   note: "Shown on your profile.", contentType: .name, capitalization: .words)) { [weak self] _, name, done in
            guard let self else { return }
            guard !name.isEmpty else { return done("Please enter your name.") }
            self.accounts.save(["name": name]) { error in
                if let error { return done(error.localizedDescription) }
                PublicProfileStore.shared.publish(name: name)
                DispatchQueue.main.async {
                    self.profile.name = name
                    self.changed()
                }
                done(nil)
            }
        }
    }

    private func editUsername() {
        let note = "\(PublicProfileStore.minimumLength) to \(PublicProfileStore.maximumLength) letters, numbers or underscores. Other members find you by it."
        push(.init(title: "Username", value: profile.username ?? "", placeholder: "username", note: note,
                   contentType: .username, capitalization: .none, prefix: "@")) { [weak self] _, text, done in
            guard let self else { return }
            let handle = PublicProfileStore.normalized(text)
            guard !handle.isEmpty else { return done("Your username can be changed, but not removed.") }
            guard handle != self.profile.username else { return done(nil) }
            PublicProfileStore.shared.claimUsername(handle) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.profile.username = handle
                        self.changed()
                    }
                    done(nil)
                case .failure(let error):
                    done(error.localizedDescription)
                }
            }
        }
    }

    private func editPhone() {
        push(.init(title: "Phone", value: profile.phoneNumber ?? "", placeholder: "123-456-7890",
                   note: "Private. Only you can see it.", keyboard: .phonePad, contentType: .telephoneNumber)) { [weak self] _, phone, done in
            guard let self else { return }
            self.accounts.save(["phoneNumber": phone]) { error in
                if let error { return done(error.localizedDescription) }
                DispatchQueue.main.async {
                    self.profile.phoneNumber = phone
                    self.changed()
                }
                done(nil)
            }
        }
    }

    ///Apple manages an Apple account's email; there is no password to confirm a change with.
    private func editEmail() {
        guard accounts.hasPasswordAccount else {
            Utilities.showAlert(on: self, title: "Managed by Apple",
                                message: "You sign in with Apple, so your email is the one on your Apple ID.")
            return
        }
        push(.init(title: "Email", value: profile.email, placeholder: "email@domain.com",
                   note: "We'll send a link to the new address. Your email changes when you open it.",
                   keyboard: .emailAddress, contentType: .emailAddress, capitalization: .none)) { [weak self] editor, email, done in
            guard let self else { return }
            guard email.contains("@"), email.contains(".") else { return done("Please enter a valid email address.") }
            self.askPassword(on: editor, for: email) { password in
                guard let password else { return done("") }
                self.accounts.changeEmail(to: email, password: password) { error in
                    if let error { return done(error.localizedDescription) }
                    done(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Utilities.showAlert(on: self, title: "Check Your Email",
                                            message: "We sent a link to \(email). Your email changes when you open it, and you'll sign in again with it.")
                    }
                }
            }
        }
    }

    ///nil when cancelled.
    private func askPassword(on presenter: UIViewController, for email: String, completion: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: "Confirm with your password",
                                      message: "Enter your password to change your email to \(email).",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Password"
            field.isSecureTextEntry = true
            field.textContentType = .password
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(nil) })
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak alert] _ in
            let password = alert?.textFields?.first?.text ?? ""
            completion(password.isEmpty ? nil : password)
        })
        presenter.present(alert, animated: true)
    }
}
