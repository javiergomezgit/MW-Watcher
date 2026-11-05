//
//  CommunityTermsController.swift
//  Bullish Square
//

import UIKit

///The community rules, agreed to once before the first post or reshare. (BS-271)
final class CommunityTermsController: UIViewController {

    // MARK: - Properties

    ///Called after the acceptance is saved; the screen has dismissed itself.
    var onAccept: (() -> Void)?

    private let agreeButton = UIButton(configuration: .filled())
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Community Guidelines"
        view.backgroundColor = ProfileStyle.background
        ProfileStyle.style(navigationController)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        isModalInPresentation = true

        let textView = UITextView()
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.text = CommunityGuidelines.text
        textView.font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        textView.textColor = ProfileStyle.text
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        let termsButton = UIButton(configuration: .plain())
        termsButton.configuration?.title = "Read the full Terms of Service"
        termsButton.configuration?.baseForegroundColor = ProfileStyle.secondaryText
        termsButton.addAction(UIAction { _ in
            guard let url = URL(string: CommunityGuidelines.termsURL) else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        AuthStyle.stylePrimary(agreeButton, title: "I Agree")
        agreeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        agreeButton.addAction(UIAction { [weak self] _ in self?.agreeTapped() }, for: .touchUpInside)
        spinner.hidesWhenStopped = true
        spinner.color = ProfileStyle.text

        let stack = UIStackView(arrangedSubviews: [textView, termsButton, agreeButton, spinner])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func agreeTapped() {
        agreeButton.isEnabled = false
        spinner.startAnimating()
        CommunityGuidelines.accept { [weak self] error in
            guard let self else { return }
            self.spinner.stopAnimating()
            self.agreeButton.isEnabled = true
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Save", message: error.localizedDescription)
            }
            let onAccept = self.onAccept
            self.dismiss(animated: true) { onAccept?() }
        }
    }
}

///The accounts you blocked, with Unblock on each. Opened from the Profile tab. (BS-271)
final class BlockedAccountsController: UITableViewController {

    private var uids: [String] = []
    private let messageLabel = UILabel()

    init() {
        super.init(style: .insetGrouped)
        title = "Blocked Accounts"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(tableView)
        messageLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = ProfileStyle.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        load()
    }

    private func load() {
        CommunityStore.shared.blockLists { [weak self] blocked, _ in
            AuthorDirectory.shared.load(Array(blocked)) {
                guard let self else { return }
                self.uids = blocked.sorted { AuthorDirectory.shared.handle($0) < AuthorDirectory.shared.handle($1) }
                self.tableView.reloadData()
                self.updateMessage()
            }
        }
    }

    private func updateMessage() {
        guard uids.isEmpty else {
            tableView.tableFooterView = nil
            return
        }
        messageLabel.text = "You haven't blocked anyone. Block someone from the … menu on their post or profile."
        messageLabel.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 80)
        tableView.tableFooterView = messageLabel
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        uids.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uid = uids[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = AuthorDirectory.shared.handle(uid)
        ProfileStyle.style(&content)
        cell.contentConfiguration = content
        ProfileStyle.style(cell)

        let unblock = UIButton(configuration: .plain())
        unblock.configuration?.title = "Unblock"
        unblock.configuration?.baseForegroundColor = ProfileStyle.accent
        unblock.addAction(UIAction { [weak self] _ in self?.unblock(uid) }, for: .touchUpInside)
        unblock.sizeToFit()
        cell.accessoryView = unblock
        return cell
    }

    private func unblock(_ uid: String) {
        CommunityStore.shared.unblock(uid) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Unblock", message: error.localizedDescription)
            }
            self.uids.removeAll { $0 == uid }
            self.tableView.reloadData()
            self.updateMessage()
        }
    }
}
