//
//  UserListController.swift
//  Bullish Square
//

import UIKit

///Who follows someone, or who they follow, newest first. Tapping a person opens their
///profile. People hidden by a block either way are left out. (BS-269)
final class UserListController: UITableViewController {

    // MARK: - Properties

    private let uid: String
    private let followers: Bool
    private var uids: [String] = []
    private lazy var emptyView = EmptyStateView(title: "", message: "")

    init(uid: String, followers: Bool) {
        self.uid = uid
        self.followers = followers
        super.init(style: .insetGrouped)
        title = followers ? "Followers" : "Following"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(tableView)
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)
        load()
    }

    private func load() {
        let store = CommunityStore.shared
        let completion: (Result<[String], Error>) -> Void = { [weak self] result in
            guard let self else { return }
            guard case .success(let uids) = result else {
                return self.show([], failed: true)
            }
            store.blockLists { blocked, blockedBy in
                let visible = uids.filter { !blocked.contains($0) && !blockedBy.contains($0) }
                AuthorDirectory.shared.load(visible) { self.show(visible, failed: false) }
            }
        }
        followers ? store.followerUIDs(of: uid, completion: completion) : store.followingUIDs(of: uid, completion: completion)
    }

    private func show(_ uids: [String], failed: Bool) {
        self.uids = uids
        refreshControl?.endRefreshing()
        tableView.reloadData()
        guard uids.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "Couldn't load this list", message: "Check your connection and try again.",
                                actionTitle: "Try again") { [weak self] in self?.load() }
        } else {
            emptyView.configure(title: followers ? "No followers yet" : "Not following anyone yet", message: "")
        }
        tableView.backgroundView = emptyView
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        uids.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uid = uids[indexPath.row]
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
        navigationController?.pushViewController(CommunityController(profileOf: uids[indexPath.row]), animated: true)
    }
}
