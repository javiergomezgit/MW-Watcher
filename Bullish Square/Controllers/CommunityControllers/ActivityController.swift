//
//  ActivityController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth

///What people did with your posts and profile: likes, reshares, comments, replies and new
///followers, newest first. Tapping a line opens the post's comments, or the follower's
///profile. People hidden by a block either way are left out. (BS-273)
///
///In-app only; push notifications need APNs set up and are a separate ticket. An admin also
///gets Reports here, in the bar, rather than another button on the Community tab.
final class ActivityController: UITableViewController {

    // MARK: - Properties

    private var items: [CommunityActivity] = []
    private lazy var emptyView = EmptyStateView(title: "", message: "")
    private let store = CommunityStore.shared

    ///When Activity was last opened on this phone, per account, for the dot on the bell.
    static func seenKey(_ uid: String) -> String { "communityActivitySeen_\(uid)" }

    static func hasUnseen(newest: Date?) -> Bool {
        guard let newest, let uid = CommunityStore.shared.currentUid else { return false }
        let seen = UserDefaults.standard.object(forKey: seenKey(uid)) as? Date ?? .distantPast
        return newest > seen
    }

    init() {
        super.init(style: .plain)
        title = "Activity"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(navigationController)
        ProfileStyle.style(tableView)
        tableView.register(ActivityCell.self, forCellReuseIdentifier: ActivityCell.reuseIdentifier)
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)
        load()
        store.isAdmin { [weak self] admin in
            guard admin, let self else { return }
            let reports = UIBarButtonItem(image: UIImage(systemName: "exclamationmark.shield"), primaryAction: UIAction { [weak self] _ in
                self?.navigationController?.pushViewController(ReportsController(), animated: true)
            })
            reports.accessibilityLabel = "Reports"
            self.navigationItem.rightBarButtonItem = reports
        }
    }

    private func load() {
        if let uid = store.currentUid {
            UserDefaults.standard.set(Date(), forKey: Self.seenKey(uid))
        }
        store.blockLists { [weak self] blocked, blockedBy in
            guard let self else { return }
            self.store.recentActivity { result in
                guard case .success(let all) = result else { return self.show([], failed: true) }
                let visible = all.filter { !blocked.contains($0.actorUid) && !blockedBy.contains($0.actorUid) }
                AuthorDirectory.shared.load(visible.map(\.actorUid)) { self.show(visible, failed: false) }
            }
        }
    }

    private func show(_ items: [CommunityActivity], failed: Bool) {
        self.items = items
        refreshControl?.endRefreshing()
        tableView.reloadData()
        guard items.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "Activity isn't available right now", message: "Check your connection and try again.",
                                actionTitle: "Try again") { [weak self] in self?.load() }
        } else {
            emptyView.configure(title: "No activity yet",
                                message: "When people like, reshare or comment on your posts, or follow you, you'll see it here.")
        }
        tableView.backgroundView = emptyView
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ActivityCell.reuseIdentifier, for: indexPath) as! ActivityCell
        cell.configure(items[indexPath.row])
        return cell
    }

    ///A follow opens the follower; anything else the post, with its comments.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        guard let postId = item.postId else {
            navigationController?.pushViewController(CommunityController(profileOf: item.actorUid), animated: true)
            return
        }
        store.post(id: postId) { [weak self] post in
            guard let self else { return }
            guard let post else {
                return Utilities.showAlert(on: self, title: "Post Unavailable", message: "This post was deleted.")
            }
            self.navigationController?.pushViewController(CommentsController(post: post), animated: true)
        }
    }
}

// MARK: - Cell

///"@wolf liked your post · 3h", with their photo.
private final class ActivityCell: UITableViewCell {

    static let reuseIdentifier = "ActivityCell"

    private let avatar = UIImageView()
    private let label = UILabel()
    private let icon = UIImageView()
    private var itemId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        ProfileStyle.style(self)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 20
        avatar.tintColor = ProfileStyle.secondaryText
        label.numberOfLines = 3
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [avatar, label, icon])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            icon.widthAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ item: CommunityActivity) {
        itemId = item.id
        let directory = AuthorDirectory.shared
        let bold = UIFont(name: "Avenir-Heavy", size: 15) ?? .systemFont(ofSize: 15, weight: .bold)
        let regular = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        let text = NSMutableAttributedString(string: directory.handle(item.actorUid),
                                             attributes: [.font: bold, .foregroundColor: ProfileStyle.text])
        let (action, symbol, tint) = Self.describe(item)
        text.append(NSAttributedString(string: " \(action)", attributes: [.font: regular, .foregroundColor: ProfileStyle.text]))
        if let snippet = item.snippet, !snippet.isEmpty {
            text.append(NSAttributedString(string: ": “\(snippet)”", attributes: [.font: regular, .foregroundColor: ProfileStyle.text]))
        }
        text.append(NSAttributedString(string: " · \(PostCell.age(of: item.createdAt))",
                                       attributes: [.font: regular, .foregroundColor: ProfileStyle.secondaryText]))
        label.attributedText = text
        icon.image = UIImage(systemName: symbol)
        icon.tintColor = tint

        avatar.image = UIImage(systemName: "person.crop.circle.fill")
        if let url = directory.profile(item.actorUid)?.photoURL {
            RemoteImageCache.shared.load(url) { [weak self] image in
                guard let self, self.itemId == item.id, let image else { return }
                self.avatar.image = image
            }
        }
    }

    private static func describe(_ item: CommunityActivity) -> (String, String, UIColor) {
        let green = UIColor(named: "uptrend") ?? .systemGreen
        switch item.kind {
        case .like: return ("liked your post", "heart.fill", UIColor(named: "downtrend") ?? .systemRed)
        case .reshare: return ("reshared your post", "arrow.2.squarepath", green)
        case .comment: return ("commented", "bubble.right.fill", ProfileStyle.accent)
        case .reply: return ("replied to you", "arrowshape.turn.up.left.fill", ProfileStyle.accent)
        case .follow: return ("started following you", "person.fill.badge.plus", green)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        itemId = nil
    }
}
