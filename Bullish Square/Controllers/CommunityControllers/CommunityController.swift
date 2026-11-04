//
//  CommunityController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth

///The Community tab's navigation stack, set up in code like the Profile tab's.
final class CommunityNavigationController: UINavigationController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewControllers = [CommunityController()]
    }
}

///The Community tab: posts from the people you follow, or the latest from everyone, 20 at a
///time. (BS-266)
///
///People you blocked and people who blocked you are left out of both feeds. A reshare shows
///the original post under "@x reshared"; originals are read once each.
final class CommunityController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Properties

    private enum Feed: Int {
        case following, discover
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let feedControl = UISegmentedControl(items: ["Following", "Discover"])
    private let refreshControl = UIRefreshControl()
    private lazy var emptyView = EmptyStateView(title: "", message: "")

    private var feed: Feed = .following
    private var posts: [Post] = []
    private var before: Date?
    private var isLoading = false
    ///Bumped on every fresh load, so an answer for a feed no longer showing is dropped.
    private var generation = 0
    private var originals: [String: Post] = [:]
    private var hidden = Set<String>()

    private let store = CommunityStore.shared
    private let directory = AuthorDirectory.shared

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Community"
        view.backgroundColor = ProfileStyle.background
        TabTitleRow(title: title, buttons: titleButtons()).install(in: self)

        feedControl.selectedSegmentIndex = feed.rawValue
        feedControl.selectedSegmentTintColor = ProfileStyle.card
        feedControl.setTitleTextAttributes([.foregroundColor: ProfileStyle.secondaryText], for: .normal)
        feedControl.setTitleTextAttributes([.foregroundColor: ProfileStyle.text], for: .selected)
        feedControl.addAction(UIAction { [weak self] _ in self?.feedChanged() }, for: .valueChanged)

        ProfileStyle.style(tableView)
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PostCell.self, forCellReuseIdentifier: PostCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        refreshControl.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)
        tableView.refreshControl = refreshControl

        for subview in [feedControl, tableView] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            feedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            feedControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            feedControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: feedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TabTitleRow.setBarHidden(true, for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TabTitleRow.setBarHidden(false, for: self, animated: animated)
    }

    ///The buttons in the tab's title row.
    private func titleButtons() -> [UIView] {
        []
    }

    // MARK: - Loading

    private func feedChanged() {
        feed = Feed(rawValue: feedControl.selectedSegmentIndex) ?? .following
        posts = []
        tableView.reloadData()
        reload()
    }

    ///From the top: the block lists first, then the newest page.
    func reload() {
        guard Auth.auth().currentUser != nil else {
            refreshControl.endRefreshing()
            posts = []
            tableView.reloadData()
            emptyView.configure(title: "Join the community",
                                message: "Sign in to follow traders, share ideas and see what people are posting.")
            tableView.backgroundView = emptyView
            return
        }
        generation += 1
        let current = generation
        isLoading = true
        directory.forgetAll()
        store.blockLists { [weak self] blocked, blockedBy in
            guard let self, current == self.generation else { return }
            self.hidden = blocked.union(blockedBy)
            self.loadPage(before: nil, generation: current)
        }
    }

    private func loadMore() {
        guard !isLoading, let before else { return }
        isLoading = true
        loadPage(before: before, generation: generation)
    }

    private func loadPage(before: Date?, generation current: Int) {
        let completion: (Result<CommunityStore.Page, Error>) -> Void = { [weak self] result in
            guard let self, current == self.generation else { return }
            switch result {
            case .failure:
                self.finish(failed: true)
            case .success(let page):
                self.before = page.before
                self.prepare(page.posts) { visible in
                    guard current == self.generation else { return }
                    self.posts = before == nil ? visible : self.posts + visible
                    self.finish(failed: false)
                }
            }
        }
        switch feed {
        case .following: store.following(before: before, completion: completion)
        case .discover: store.discover(before: before, completion: completion)
        }
    }

    ///Drops what is hidden, reads the originals of reshares and every author on the page,
    ///then hands back what to show.
    private func prepare(_ page: [Post], completion: @escaping ([Post]) -> Void) {
        let visible = page.filter { !hidden.contains($0.authorUid) && !hidden.contains($0.reshareOfAuthor ?? "") }
        let missing = Set(visible.compactMap(\.reshareOf)).subtracting(originals.keys)
        let group = DispatchGroup()
        for id in missing {
            group.enter()
            store.post(id: id) { [weak self] original in
                if let original { self?.originals[id] = original }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let authors = visible.map(\.authorUid) + visible.compactMap { $0.reshareOf.flatMap { self.originals[$0]?.authorUid } }
            self.directory.load(authors) { completion(visible) }
        }
    }

    private func finish(failed: Bool) {
        isLoading = false
        refreshControl.endRefreshing()
        tableView.reloadData()
        updateEmptyState(failed: failed)
    }

    private func updateEmptyState(failed: Bool) {
        guard posts.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "Community isn't available right now",
                                message: "Check your connection and try again.",
                                actionTitle: "Try again") { [weak self] in self?.reload() }
        } else if feed == .following {
            emptyView.configure(title: "Your feed is empty",
                                message: "Follow people to see their posts here, or see what everyone is sharing.",
                                actionTitle: "Discover") { [weak self] in
                self?.feedControl.selectedSegmentIndex = Feed.discover.rawValue
                self?.feedChanged()
            }
        } else {
            emptyView.configure(title: "No posts yet", message: "Be the first to share an idea.")
        }
        tableView.backgroundView = emptyView
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.reuseIdentifier, for: indexPath) as! PostCell
        let post = posts[indexPath.row]
        let shown = post.reshareOf.map { originals[$0] } ?? post
        cell.configure(shown: shown, resharedBy: post.isReshare ? post.authorUid : nil,
                       liked: false, reshared: false, isOwn: shown?.authorUid == store.currentUid)
        cell.onTicker = { [weak self] symbol in self?.openChart(symbol) }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= posts.count - 3 { loadMore() }
    }

    // MARK: - Navigation

    ///The same chart a search result opens, loading its own price and logo.
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
