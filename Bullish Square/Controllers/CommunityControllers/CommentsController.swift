//
//  CommentsController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth
import SafariServices

///A post with its comments under it, oldest first, and a field to add one. Reply starts the
///text with "@name" and tells that person too. Comments by people hidden by a block either
///way are left out. (BS-273)
final class CommentsController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {

    // MARK: - Properties

    private enum Section: Int, CaseIterable {
        case post, comments
    }

    private let post: Post
    ///Called with the new count after adding or deleting, so the feed's button can follow.
    var onCountChanged: ((Int) -> Void)?
    ///Opens with the keyboard up, as when the comment button was tapped to write.
    var startsWriting = false

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let inputField = UITextView()
    private let placeholder = UILabel()
    private let sendButton = UIButton(type: .system)
    private lazy var inputHeight = inputField.heightAnchor.constraint(equalToConstant: 36)
    private let footerLabel = UILabel()

    private var comments: [Comment] = []
    private var hidden = Set<String>()
    private var blockedByMe = Set<String>()
    private var replyToUid: String?
    private var isLoading = true
    private var failed = false

    private let store = CommunityStore.shared
    private let directory = AuthorDirectory.shared

    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
        title = "Comments"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ProfileStyle.background
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(navigationController)

        ProfileStyle.style(tableView)
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(PostCell.self, forCellReuseIdentifier: PostCell.reuseIdentifier)
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)

        setUpInputBar()
        for subview in [tableView, inputBar] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if startsWriting, Auth.auth().currentUser != nil {
            startsWriting = false
            inputField.becomeFirstResponder()
        }
    }

    private func setUpInputBar() {
        inputBar.backgroundColor = ProfileStyle.card

        inputField.font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        inputField.textColor = ProfileStyle.text
        inputField.backgroundColor = ProfileStyle.background
        inputField.layer.cornerRadius = 18
        inputField.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        inputField.isScrollEnabled = false
        inputField.delegate = self

        placeholder.text = "Add a comment"
        placeholder.font = inputField.font
        placeholder.textColor = ProfileStyle.placeholder
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        inputField.addSubview(placeholder)

        var send = UIButton.Configuration.plain()
        send.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28))
        send.baseForegroundColor = UIColor(named: "uptrend") ?? ProfileStyle.accent
        send.contentInsets = .zero
        sendButton.configuration = send
        sendButton.accessibilityLabel = "Send"
        sendButton.isEnabled = false
        sendButton.addAction(UIAction { [weak self] _ in self?.sendTapped() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [inputField, sendButton])
        row.spacing = 8
        row.alignment = .bottom
        row.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: inputBar.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: inputBar.layoutMarginsGuide.trailingAnchor),
            inputHeight,
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            placeholder.leadingAnchor.constraint(equalTo: inputField.leadingAnchor, constant: 10),
            placeholder.centerYAnchor.constraint(equalTo: inputField.topAnchor, constant: 18)
        ])

        if Auth.auth().currentUser == nil {
            placeholder.text = "Sign in to comment"
            inputField.isEditable = false
        }
    }

    // MARK: - Loading

    private func load() {
        store.blockLists { [weak self] blocked, blockedBy in
            guard let self else { return }
            self.hidden = blocked.union(blockedBy)
            self.blockedByMe = blocked
            self.store.comments(onPost: self.post.id) { result in
                switch result {
                case .failure:
                    self.show([], failed: true)
                case .success(let all):
                    let visible = all.filter { !self.hidden.contains($0.authorUid) }
                    self.directory.load(visible.map(\.authorUid) + [self.post.authorUid]) {
                        self.show(visible, failed: false)
                    }
                }
            }
        }
    }

    private func show(_ comments: [Comment], failed: Bool) {
        self.comments = comments
        self.failed = failed
        isLoading = false
        tableView.refreshControl?.endRefreshing()
        tableView.reloadData()
        updateFooter()
        if !failed { onCountChanged?(comments.count) }
    }

    ///Under the post, so it doesn't cover it as a background would.
    private func updateFooter() {
        guard comments.isEmpty, !isLoading else {
            tableView.tableFooterView = nil
            return
        }
        footerLabel.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 80)
        footerLabel.numberOfLines = 0
        footerLabel.text = failed ? "Comments couldn't be loaded. Pull to try again." : "No comments yet. Start the conversation."
        footerLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        footerLabel.textColor = ProfileStyle.secondaryText
        footerLabel.textAlignment = .center
        tableView.tableFooterView = footerLabel
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .post ? 1 : comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if Section(rawValue: indexPath.section) == .post {
            let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.reuseIdentifier, for: indexPath) as! PostCell
            cell.configure(shown: post, resharedBy: nil, liked: false, reshared: false, isOwn: post.authorUid == store.currentUid)
            cell.setActionsHidden(true)
            cell.onAuthor = { [weak self] in self?.openProfile(self?.post.authorUid ?? "") }
            cell.onTicker = { [weak self] symbol in self?.openChart(symbol) }
            cell.onLink = { [weak self] url in self?.openLink(url) }
            cell.onPhoto = { [weak self] urls, index in
                self?.present(PhotoViewerController(urls: urls, startIndex: index), animated: true)
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier, for: indexPath) as! CommentCell
        let comment = comments[indexPath.row]
        cell.configure(comment)
        cell.onAuthor = { [weak self] in self?.openProfile(comment.authorUid) }
        cell.onReply = { [weak self] in self?.reply(to: comment) }
        cell.onMore = { [weak self, weak cell] in self?.moreTapped(comment, from: cell) }
        cell.onTicker = { [weak self] symbol in self?.openChart(symbol) }
        cell.onLink = { [weak self] url in self?.openLink(url) }
        return cell
    }

    // MARK: - Writing

    func textViewDidChange(_ textView: UITextView) {
        let text = textView.text ?? ""
        placeholder.isHidden = !text.isEmpty
        sendButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if text.isEmpty { replyToUid = nil }
        //Grows to four lines, then scrolls.
        let fitting = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        let height = min(max(36, fitting), 120)
        textView.isScrollEnabled = fitting > 120
        if inputHeight.constant != height { inputHeight.constant = height }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString? ?? ""
        return current.replacingCharacters(in: range, with: text).count <= Comment.textMaximumLength
    }

    private func reply(to comment: Comment) {
        guard Auth.auth().currentUser != nil else { return signInAlert() }
        replyToUid = comment.authorUid == store.currentUid ? nil : comment.authorUid
        let mention = directory.handle(comment.authorUid)
        if !(inputField.text ?? "").hasPrefix(mention) {
            inputField.text = "\(mention) " + (inputField.text ?? "")
        }
        textViewDidChange(inputField)
        inputField.becomeFirstResponder()
    }

    private func sendTapped() {
        let text = inputField.text ?? ""
        //The community guidelines' filter, as for posts (BS-271).
        guard !CommunityGuidelines.containsObjectionableLanguage(text) else {
            return Utilities.showAlert(on: self, title: "Can't Comment",
                                       message: "Your comment contains language that isn't allowed in Community. Edit it and try again.")
        }
        requireTerms { [weak self] in self?.send(text) }
    }

    private func send(_ text: String) {
        sendButton.isEnabled = false
        store.addComment(text, to: post, replyingTo: replyToUid) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.sendButton.isEnabled = true
                Utilities.showAlert(on: self, title: "Can't Comment", message: error.localizedDescription)
            case .success(let comment):
                self.inputField.text = ""
                self.textViewDidChange(self.inputField)
                self.comments.append(comment)
                self.tableView.reloadData()
                self.updateFooter()
                self.onCountChanged?(self.comments.count)
                let last = IndexPath(row: self.comments.count - 1, section: Section.comments.rawValue)
                self.tableView.scrollToRow(at: last, at: .bottom, animated: true)
            }
        }
    }

    ///Runs `action` once the community terms are accepted, asking first if they aren't.
    private func requireTerms(_ action: @escaping () -> Void) {
        guard Auth.auth().currentUser != nil else { return signInAlert() }
        CommunityGuidelines.hasAccepted { [weak self] accepted in
            guard let self else { return }
            if accepted { return action() }
            let terms = CommunityTermsController()
            terms.onAccept = action
            self.present(UINavigationController(rootViewController: terms), animated: true)
        }
    }

    private func signInAlert() {
        Utilities.showAlert(on: self, title: "Sign In", message: "Sign in to comment in Community.")
    }

    // MARK: - Delete, report, block

    ///Your own comment, or any on your own post, can be deleted; anyone else's reported, and
    ///its author blocked.
    private func moreTapped(_ comment: Comment, from cell: UITableViewCell?) {
        let uid = store.currentUid
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if comment.authorUid == uid || post.authorUid == uid {
            sheet.addAction(UIAlertAction(title: "Delete Comment", style: .destructive) { [weak self] _ in
                self?.delete(comment)
            })
        }
        if comment.authorUid != uid, uid != nil {
            sheet.addAction(UIAlertAction(title: "Report Comment", style: .default) { [weak self] _ in
                self?.report(comment, from: cell)
            })
            sheet.addAction(UIAlertAction(title: "Block \(directory.handle(comment.authorUid))", style: .destructive) { [weak self] _ in
                self?.confirmBlock(comment.authorUid)
            })
        }
        guard !sheet.actions.isEmpty else { return }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = cell ?? view
        present(sheet, animated: true)
    }

    private func delete(_ comment: Comment) {
        store.deleteComment(comment) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Delete", message: error.localizedDescription)
            }
            self.comments.removeAll { $0.id == comment.id }
            self.tableView.reloadData()
            self.updateFooter()
            self.onCountChanged?(self.comments.count)
        }
    }

    private func report(_ comment: Comment, from source: UIView?) {
        let sheet = UIAlertController(title: "Report Comment", message: "Why are you reporting this?", preferredStyle: .actionSheet)
        for reason in CommunityStore.ReportReason.allCases {
            sheet.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                self?.store.report(postId: comment.postId, commentId: comment.id, userUid: comment.authorUid, reason: reason) { error in
                    guard let self else { return }
                    if let error {
                        return Utilities.showAlert(on: self, title: "Can't Report", message: error.localizedDescription)
                    }
                    self.reportSent(userUid: comment.authorUid)
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = source ?? view
        present(sheet, animated: true)
    }

    private func reportSent(userUid: String) {
        let alert = UIAlertController(title: "Thanks for reporting",
                                      message: "We review reports within 24 hours. You can also block \(directory.handle(userUid)) so you no longer see each other.",
                                      preferredStyle: .alert)
        if !blockedByMe.contains(userUid) {
            alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in self?.block(userUid) })
        }
        alert.addAction(UIAlertAction(title: blockedByMe.contains(userUid) ? "OK" : "Not Now", style: .cancel))
        present(alert, animated: true)
    }

    private func confirmBlock(_ uid: String) {
        let alert = UIAlertController(title: "Block \(directory.handle(uid))?",
                                      message: "You won't see each other's posts or comments, and neither of you can follow the other. They aren't told.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in self?.block(uid) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func block(_ uid: String) {
        store.block(uid) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Block", message: error.localizedDescription)
            }
            self.hidden.insert(uid)
            self.blockedByMe.insert(uid)
            self.comments.removeAll { $0.authorUid == uid }
            self.tableView.reloadData()
            self.updateFooter()
            //Blocking the post's author leaves nothing here to see.
            if uid == self.post.authorUid {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - Navigation

    private func openProfile(_ uid: String) {
        guard !uid.isEmpty else { return }
        navigationController?.pushViewController(CommunityController(profileOf: uid), animated: true)
    }

    private func openLink(_ url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        present(SFSafariViewController(url: url, configuration: config), animated: true)
    }

    private func openChart(_ symbol: String) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else { return }
        destination.informationStockTicker = TickersCurrentValues(ticker: symbol, marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
        destination.nameTicker = symbol
        destination.imageCompany = UIImage(named: "mw-logo")
        destination.loadsQuoteAndLogo = true
        navigationController?.pushViewController(destination, animated: true)
    }
}
