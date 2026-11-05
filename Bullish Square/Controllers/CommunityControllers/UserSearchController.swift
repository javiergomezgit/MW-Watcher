//
//  UserSearchController.swift
//  Bullish Square
//

import UIKit

///Find people by @username: results as you type, from the start of the handle. Tapping one
///opens their profile. People blocked either way are left out. (BS-270)
final class UserSearchController: UITableViewController, UISearchBarDelegate {

    // MARK: - Properties

    private let searchBar = UISearchBar()
    private var results: [String] = []
    private var hidden = Set<String>()
    private var searchTimer: Timer?
    ///The text of the latest search, so a slower earlier answer can't replace it.
    private var latestQuery = ""
    ///The hint, or "No one found", under the search bar. A background view covered the whole
    ///table and sat under the navigation title.
    private let messageLabel = UILabel()

    init() {
        super.init(style: .insetGrouped)
        title = "Find People"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(tableView)
        tableView.keyboardDismissMode = .onDrag

        searchBar.placeholder = "Search @username"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = ProfileStyle.accent
        searchBar.searchTextField.textColor = ProfileStyle.text
        searchBar.delegate = self
        searchBar.sizeToFit()
        tableView.tableHeaderView = searchBar

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = ProfileStyle.secondaryText

        CommunityStore.shared.blockLists { [weak self] blocked, blockedBy in
            self?.hidden = blocked.union(blockedBy)
        }
        showHint()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    // MARK: - Searching

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        let query = PublicProfileStore.normalized(searchText)
        latestQuery = query
        guard !query.isEmpty else {
            results = []
            tableView.reloadData()
            return showHint()
        }
        //Waits for a pause in typing, so each keystroke isn't a read.
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.search(query)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func search(_ query: String) {
        CommunityStore.shared.searchUsernames(prefix: query) { [weak self] matches in
            guard let self, query == self.latestQuery else { return }
            let uids = matches.map(\.uid).filter { !self.hidden.contains($0) }
            AuthorDirectory.shared.load(uids) {
                guard query == self.latestQuery else { return }
                self.results = uids
                self.tableView.reloadData()
                self.showMessage(uids.isEmpty ? "No @username starts with \"\(query)\"." : nil)
            }
        }
    }

    private func showHint() {
        showMessage("Type the start of someone's @username.")
    }

    private func showMessage(_ text: String?) {
        guard let text else {
            tableView.tableFooterView = nil
            return
        }
        messageLabel.text = text
        messageLabel.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 64)
        tableView.tableFooterView = messageLabel
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uid = results[indexPath.row]
        let directory = AuthorDirectory.shared
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = directory.handle(uid)
        content.secondaryText = directory.profile(uid)?.name
        if directory.isAutomated(uid) {
            //Bots are labelled in every list they appear in. (BS-279)
            content.secondaryText = ["Automated", directory.profile(uid)?.name].compactMap { $0 }.joined(separator: " · ")
        }
        content.image = UIImage(systemName: "person.crop.circle.fill")
        content.imageProperties.maximumSize = CGSize(width: 36, height: 36)
        content.imageProperties.cornerRadius = 18
        ProfileStyle.style(&content)
        content.imageProperties.tintColor = ProfileStyle.secondaryText
        cell.contentConfiguration = content
        ProfileStyle.style(cell)
        cell.accessoryType = .disclosureIndicator

        if let url = directory.profile(uid)?.photoURL {
            RemoteImageCache.shared.load(url) { [weak tableView] image in
                guard let image, let cell = tableView?.cellForRow(at: indexPath),
                      var content = cell.contentConfiguration as? UIListContentConfiguration else { return }
                content.image = image
                cell.contentConfiguration = content
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBar.resignFirstResponder()
        navigationController?.pushViewController(CommunityController(profileOf: results[indexPath.row]), animated: true)
    }
}
