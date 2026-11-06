//
//  CommunityController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth
import SafariServices

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
///Opened with a uid it is that person's profile instead: their details, counts and Follow
///above their posts, with the same cards and actions as the feeds. (BS-269)
///
///Opened with a ticker it is the posts that mention `$TICKER`, from a stock's chart, with a
///button to post about it. (BS-287)
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
    ///Who you blocked, as opposed to who blocked you: a profile offers Unblock for these.
    private var blockedByMe = Set<String>()
    ///Posts you liked, by their own id: a reshare's likes are the reshare's. (BS-268, BS-292)
    private var liked = Set<String>()
    ///Posts you reshared, by the original's id.
    private var reshared = Set<String>()
    ///Comment counts by each post's own id: a reshare has its own comments. (BS-273, BS-292)
    private var commentCounts: [String: Int] = [:]
    ///The bell, which shows a dot when there is activity not seen yet. (BS-273)
    private lazy var activityButton = titleButton("bell", label: "Activity") { [weak self] in self?.openActivity() }

    private let store = CommunityStore.shared
    private let directory = AuthorDirectory.shared

    ///nil for the tab's feeds; a uid for that person's profile. (BS-269)
    private let profileUid: String?
    private lazy var profileHeader = CommunityProfileHeaderView()
    private var profileCounts: CommunityStore.Counts?
    private var isFollowingProfile: Bool?

    ///A ticker's posts: the upper-case symbol, and the post the chart starts. (BS-287)
    private let ticker: String?
    private let tickerDraft: (() -> (text: String, photos: [UIImage]))?

    ///The Community tab itself, as opposed to a profile or a ticker's posts.
    private var isTab: Bool { profileUid == nil && ticker == nil }

    init(profileOf uid: String? = nil) {
        profileUid = uid
        ticker = nil
        tickerDraft = nil
        super.init(nibName: nil, bundle: nil)
    }

    ///Posts about `symbol`; `draft` is what the Post button starts with.
    init(ticker symbol: String, draft: @escaping () -> (text: String, photos: [UIImage])) {
        profileUid = nil
        ticker = symbol.uppercased()
        tickerDraft = draft
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ProfileStyle.background
        if isTab {
            title = "Community"
            TabTitleRow(title: title, buttons: titleButtons()).install(in: self)
        } else if let ticker {
            title = "$\(ticker)"
            navigationItem.largeTitleDisplayMode = .never
            ProfileStyle.style(navigationController)
            let post = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), primaryAction: UIAction { [weak self] _ in
                self?.postAboutTicker()
            })
            post.accessibilityLabel = "Post about \(ticker)"
            navigationItem.rightBarButtonItem = post
        } else {
            navigationItem.largeTitleDisplayMode = .never
            ProfileStyle.style(navigationController)
            setUpProfileHeader()
        }

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

        let showsFeeds = isTab
        for subview in (showsFeeds ? [feedControl, tableView] : [tableView]) as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        if showsFeeds {
            NSLayoutConstraint.activate([
                feedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
                feedControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                feedControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                tableView.topAnchor.constraint(equalTo: feedControl.bottomAnchor, constant: 8)
            ])
        } else {
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reload()
    }

    ///The tab draws its own title row; a profile or a ticker uses the navigation bar and its
    ///back button.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TabTitleRow.setBarHidden(isTab, for: self, animated: animated)
        if isTab { refreshTitleButtons() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isTab {
            TabTitleRow.setBarHidden(false, for: self, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeProfileHeader()
    }

    ///The buttons in the tab's title row.
    private func titleButtons() -> [UIView] {
        return [activityButton,
                titleButton("magnifyingglass", label: "Find people") { [weak self] in self?.findPeopleTapped() },
                titleButton("square.and.pencil", label: "New post") { [weak self] in self?.composeTapped() }]
    }

    ///The bell's dot, each time the tab appears.
    private func refreshTitleButtons() {
        guard Auth.auth().currentUser != nil else { return setActivityDot(false) }
        store.newestActivityDate { [weak self] newest in
            self?.setActivityDot(ActivityController.hasUnseen(newest: newest))
        }
    }

    private func setActivityDot(_ unseen: Bool) {
        let symbol = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        if unseen {
            let palette = symbol.applying(UIImage.SymbolConfiguration(paletteColors: [UIColor(named: "downtrend") ?? .systemRed, .label]))
            activityButton.setImage(UIImage(systemName: "bell.badge", withConfiguration: palette), for: .normal)
            activityButton.accessibilityLabel = "Activity, new"
        } else {
            activityButton.setImage(UIImage(systemName: "bell", withConfiguration: symbol), for: .normal)
            activityButton.accessibilityLabel = "Activity"
        }
    }

    private func titleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
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
        if profileUid != nil { loadProfileHeader() }
        store.blockLists { [weak self] blocked, blockedBy in
            guard let self, current == self.generation else { return }
            self.hidden = blocked.union(blockedBy)
            self.blockedByMe = blocked
            self.updateProfileMenu()
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
        if let profileUid {
            return store.posts(byUser: profileUid, before: before, completion: completion)
        }
        if let ticker {
            return store.posts(aboutTicker: ticker, before: before, completion: completion)
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
            let ids = visible.map(\.id)
            let originalIDs = visible.map { $0.reshareOf ?? $0.id }
            let group = DispatchGroup()
            group.enter()
            self.directory.load(authors) { group.leave() }
            group.enter()
            self.store.likedPostIDs(ids) { ids in self.liked.formUnion(ids); group.leave() }
            group.enter()
            self.store.resharedPostIDs(originalIDs) { ids in self.reshared.formUnion(ids); group.leave() }
            group.enter()
            self.store.commentCounts(ids) { counts in self.commentCounts.merge(counts) { $1 }; group.leave() }
            group.notify(queue: .main) { completion(visible) }
        }
    }

    private func finish(failed: Bool) {
        isLoading = false
        refreshControl.endRefreshing()
        tableView.reloadData()
        updateEmptyState(failed: failed)
    }

    private func updateEmptyState(failed: Bool) {
        if profileUid != nil {
            return showProfileFooter(failed: failed)
        }
        guard posts.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "Community isn't available right now",
                                message: "Check your connection and try again.",
                                actionTitle: "Try again") { [weak self] in self?.reload() }
        } else if let ticker {
            emptyView.configure(title: "No posts about $\(ticker) yet",
                                message: "Be the first to share your take.",
                                actionTitle: "Post") { [weak self] in self?.postAboutTicker() }
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
        let original = post.reshareOf.flatMap { originals[$0] }
        //The reshare button reshares the original; likes and comments are the row's own.
        let target = post.isReshare ? original : post
        cell.configure(post, original: original,
                       liked: liked.contains(post.id),
                       reshared: target.map { reshared.contains($0.id) } ?? false,
                       isOwn: target?.authorUid == store.currentUid,
                       comments: commentCounts[post.id])
        cell.onLike = { [weak self] in self?.likeTapped(post.id) }
        cell.onComment = { [weak self] in self?.openComments(post.id) }
        if let target {
            cell.onReshare = { [weak self] in self?.reshareTapped(target.id, from: cell) }
        }
        cell.onTicker = { [weak self] symbol in self?.openChart(symbol) }
        cell.onLink = { [weak self] url in self?.openLink(url) }
        cell.onAuthor = { [weak self] in self?.openProfile(post.authorUid) }
        if let author = original?.authorUid {
            cell.onOriginalAuthor = { [weak self] in self?.openProfile(author) }
        }
        cell.onPhoto = { [weak self] urls, index in
            self?.present(PhotoViewerController(urls: urls, startIndex: index), animated: true)
        }
        cell.onMore = { [weak self] in self?.moreTapped(post, from: cell) }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= posts.count - 3 { loadMore() }
    }

    // MARK: - Likes and reshares

    ///The current copy of a post whose content shows, from the feed or the originals.
    private func shownPost(_ id: String) -> Post? {
        originals[id] ?? posts.first { $0.id == id }
    }

    ///Changes a shown post's counts everywhere it appears: as itself and as reshares' original.
    private func adjust(_ id: String, likes: Int = 0, reshares: Int = 0) {
        for index in posts.indices where posts[index].id == id {
            posts[index].likeCount = max(0, posts[index].likeCount + likes)
            posts[index].reshareCount = max(0, posts[index].reshareCount + reshares)
        }
        if var original = originals[id] {
            original.likeCount = max(0, original.likeCount + likes)
            original.reshareCount = max(0, original.reshareCount + reshares)
            originals[id] = original
        }
    }

    ///Shows the change at once and puts it back if the server refuses.
    private func likeTapped(_ id: String) {
        guard let post = shownPost(id) else { return }
        let wasLiked = liked.contains(id)
        setLiked(id, !wasLiked)
        adjust(id, likes: wasLiked ? -1 : 1)
        tableView.reloadData()
        let done: (Error?) -> Void = { [weak self] error in
            guard let self, error != nil else { return }
            self.setLiked(id, wasLiked)
            self.adjust(id, likes: wasLiked ? 1 : -1)
            self.tableView.reloadData()
        }
        wasLiked ? store.unlike(post, completion: done) : store.like(post, completion: done)
    }

    private func setLiked(_ id: String, _ isLiked: Bool) {
        if isLiked { liked.insert(id) } else { liked.remove(id) }
    }

    ///Reshares at once; undoing asks first, as it removes your post.
    private func reshareTapped(_ id: String, from cell: UITableViewCell) {
        guard let post = shownPost(id), post.authorUid != store.currentUid || reshared.contains(id) else { return }
        guard reshared.contains(id) else { return reshare(post) }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Undo Reshare", style: .destructive) { [weak self] _ in self?.unreshare(post) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = cell
        present(sheet, animated: true)
    }

    private func reshare(_ post: Post) {
        requireTerms { [weak self] in self?.confirmedReshare(post) }
    }

    private func confirmedReshare(_ post: Post) {
        reshared.insert(post.id)
        adjust(post.id, reshares: 1)
        tableView.reloadData()
        store.reshare(post) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let mine):
                self.originals[post.id] = self.shownPost(post.id)
                //Following leaves out your own posts, reshares included, and a reshare has no
                //text, so no $TICKER of its own.
                if self.profileUid != nil || (self.isTab && self.feed == .discover) { self.posts.insert(mine, at: 0) }
                self.tableView.reloadData()
            case .failure(let error):
                self.reshared.remove(post.id)
                self.adjust(post.id, reshares: -1)
                self.tableView.reloadData()
                Utilities.showAlert(on: self, title: "Can't Reshare", message: error.localizedDescription)
            }
        }
    }

    private func unreshare(_ post: Post) {
        store.unreshare(post) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Undo", message: error.localizedDescription)
            }
            self.reshared.remove(post.id)
            self.adjust(post.id, reshares: -1)
            self.posts.removeAll { $0.reshareOf == post.id && $0.authorUid == self.store.currentUid }
            self.tableView.reloadData()
            self.updateEmptyState(failed: false)
        }
    }

    // MARK: - Posting

    private func composeTapped() {
        guard Auth.auth().currentUser != nil else {
            return Utilities.showAlert(on: self, title: "Sign In", message: "Sign in to post in Community.")
        }
        requireTerms { [weak self] in self?.openComposer() }
    }

    private func openComposer() {
        let composer = ComposePostController()
        composer.onPosted = { [weak self] post in
            guard let self else { return }
            //Following leaves out your own posts, so go to Discover, where the new one is first.
            if self.isTab, self.feed == .following {
                self.feedControl.selectedSegmentIndex = Feed.discover.rawValue
                return self.feedChanged()
            }
            self.posts.insert(post, at: 0)
            self.tableView.backgroundView = nil
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: true)
        }
        present(UINavigationController(rootViewController: composer), animated: true)
    }

    ///The chart's draft and picture; the new post shows at the top if it still names the
    ///ticker, since the text can be changed before posting.
    private func postAboutTicker() {
        guard let ticker, let draft = tickerDraft?() else { return }
        PostToCommunity.start(text: draft.text, photos: draft.photos, from: self) { [weak self] post in
            guard let self, post.tickers.contains(ticker) else { return }
            self.posts.insert(post, at: 0)
            self.tableView.backgroundView = nil
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: true)
        }
    }

    ///Your own post (or reshare) can be deleted; anyone else's reported, and its author
    ///blocked. (BS-271)
    private func moreTapped(_ post: Post, from cell: UITableViewCell) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if post.authorUid == store.currentUid {
            sheet.addAction(UIAlertAction(title: post.isReshare ? "Undo Reshare" : "Delete Post", style: .destructive) { [weak self] _ in
                self?.delete(post)
            })
        }
        let shown = post.reshareOf.map { originals[$0] } ?? post
        if let shown, shown.authorUid != store.currentUid {
            let handle = directory.handle(shown.authorUid)
            sheet.addAction(UIAlertAction(title: "Report Post", style: .default) { [weak self] _ in
                self?.report(postId: shown.id, userUid: shown.authorUid, from: cell)
            })
            sheet.addAction(UIAlertAction(title: "Block \(handle)", style: .destructive) { [weak self] _ in
                self?.confirmBlock(shown.authorUid)
            })
        }
        guard !sheet.actions.isEmpty else { return }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = cell
        present(sheet, animated: true)
    }

    private func delete(_ post: Post) {
        store.deletePost(post) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Delete", message: error.localizedDescription)
            }
            self.posts.removeAll { $0.id == post.id }
            self.tableView.reloadData()
            self.updateEmptyState(failed: false)
        }
    }

    // MARK: - Profile

    private func setUpProfileHeader() {
        profileHeader.onFollow = { [weak self] in self?.followTapped() }
        profileHeader.onFollowers = { [weak self] in self?.openList(followers: true) }
        profileHeader.onFollowing = { [weak self] in self?.openList(followers: false) }
        //The posts are already below the header; the count takes you to them.
        profileHeader.onPosts = { [weak self] in
            guard let self, !self.posts.isEmpty else { return }
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
        tableView.tableHeaderView = profileHeader
    }

    ///The header's height follows its content and the table's width.
    private func sizeProfileHeader() {
        guard profileUid != nil, tableView.bounds.width > 0 else { return }
        let size = profileHeader.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        guard profileHeader.frame.size != size else { return }
        profileHeader.frame = CGRect(origin: .zero, size: size)
        tableView.tableHeaderView = profileHeader
    }

    private func loadProfileHeader() {
        guard let uid = profileUid else { return }
        let isOwn = uid == store.currentUid
        profileHeader.setPreview(isOwn)
        profileHeader.setCounts(profileCounts)
        directory.load([uid]) { [weak self] in
            guard let self else { return }
            //The header shows the @username large; the bar stays empty so it isn't said twice.
            //The back button on screens opened from here still reads it.
            self.navigationItem.backButtonTitle = self.directory.handle(uid)
            self.profileHeader.configure(uid: uid)
            self.view.setNeedsLayout()
        }
        store.counts(for: uid) { [weak self] counts in
            self?.profileCounts = counts
            self?.profileHeader.setCounts(counts)
        }
        guard !isOwn else { return profileHeader.setFollow(isOwn: true, isFollowing: nil) }
        store.isFollowing(uid) { [weak self] following in
            guard let self else { return }
            self.isFollowingProfile = following
            //No Follow while a block stands either way; the rules would refuse it.
            self.profileHeader.setFollow(isOwn: self.hidden.contains(uid), isFollowing: following)
            self.view.setNeedsLayout()
        }
    }

    ///Changes at once, with the follower count; put back if the server refuses.
    private func followTapped() {
        guard let uid = profileUid, let wasFollowing = isFollowingProfile else { return }
        setFollowing(!wasFollowing)
        profileHeader.setFollowEnabled(false)
        let done: (Error?) -> Void = { [weak self] error in
            guard let self else { return }
            self.profileHeader.setFollowEnabled(true)
            guard let error else { return }
            self.setFollowing(wasFollowing)
            Utilities.showAlert(on: self, title: wasFollowing ? "Can't Unfollow" : "Can't Follow", message: error.localizedDescription)
        }
        wasFollowing ? store.unfollow(uid, completion: done) : store.follow(uid, completion: done)
    }

    private func setFollowing(_ following: Bool) {
        if let before = isFollowingProfile, before != following, var counts = profileCounts {
            counts.followers = max(0, counts.followers + (following ? 1 : -1))
            profileCounts = counts
            profileHeader.setCounts(counts)
        }
        isFollowingProfile = following
        profileHeader.setFollow(isOwn: false, isFollowing: following)
    }

    ///Under the header, so it doesn't cover it as a background would.
    private func showProfileFooter(failed: Bool) {
        guard posts.isEmpty else {
            tableView.tableFooterView = nil
            return
        }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 80))
        label.numberOfLines = 0
        if let uid = profileUid, blockedByMe.contains(uid) {
            label.text = "You blocked \(directory.handle(uid)). Unblock them from the … menu to see their posts."
        } else if let uid = profileUid, hidden.contains(uid) {
            label.text = "This account isn't available."
        } else {
            label.text = failed ? "Posts couldn't be loaded. Pull to try again." : "No posts yet."
        }
        label.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        label.textColor = ProfileStyle.secondaryText
        label.textAlignment = .center
        tableView.tableFooterView = label
    }

    private func openList(followers: Bool) {
        guard let uid = profileUid else { return }
        navigationController?.pushViewController(UserListController(uid: uid, followers: followers), animated: true)
    }

    // MARK: - Guidelines, reports and blocks (BS-271)

    ///Runs `action` once the community terms are accepted, asking first if they aren't.
    private func requireTerms(_ action: @escaping () -> Void) {
        CommunityGuidelines.hasAccepted { [weak self] accepted in
            guard let self else { return }
            if accepted { return action() }
            let terms = CommunityTermsController()
            terms.onAccept = action
            self.present(UINavigationController(rootViewController: terms), animated: true)
        }
    }

    ///A post, or with no post an account, with a reason. Then offers to block them too.
    private func report(postId: String?, userUid: String, from source: UIView?) {
        let sheet = UIAlertController(title: postId == nil ? "Report Account" : "Report Post",
                                      message: "Why are you reporting this?", preferredStyle: .actionSheet)
        for reason in CommunityStore.ReportReason.allCases {
            sheet.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                self?.store.report(postId: postId, userUid: userUid, reason: reason) { error in
                    guard let self else { return }
                    if let error {
                        return Utilities.showAlert(on: self, title: "Can't Report", message: error.localizedDescription)
                    }
                    self.reportSent(userUid: userUid)
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
                                      message: "You won't see each other's posts, and neither of you can follow the other. They aren't told.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in self?.block(uid) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    ///Their posts leave this screen at once; on their profile, it closes.
    private func block(_ uid: String) {
        store.block(uid) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Block", message: error.localizedDescription)
            }
            self.hidden.insert(uid)
            self.blockedByMe.insert(uid)
            self.posts.removeAll { $0.authorUid == uid || $0.reshareOfAuthor == uid }
            self.tableView.reloadData()
            self.updateEmptyState(failed: false)
            if self.profileUid == uid {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func unblock(_ uid: String) {
        store.unblock(uid) { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Unblock", message: error.localizedDescription)
            }
            self.reload()
        }
    }

    ///On someone else's profile: Report, and Block or Unblock. Follow is hidden while either
    ///of you has blocked the other.
    private func updateProfileMenu() {
        guard let uid = profileUid, uid != store.currentUid else { return }
        var actions = [UIAction(title: "Report Account", image: UIImage(systemName: "flag")) { [weak self] _ in
            self?.report(postId: nil, userUid: uid, from: nil)
        }]
        if blockedByMe.contains(uid) {
            actions.append(UIAction(title: "Unblock", image: UIImage(systemName: "hand.raised.slash")) { [weak self] _ in
                self?.unblock(uid)
            })
        } else {
            actions.append(UIAction(title: "Block", image: UIImage(systemName: "hand.raised"), attributes: .destructive) { [weak self] _ in
                self?.confirmBlock(uid)
            })
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: actions))
        if hidden.contains(uid) {
            profileHeader.setFollow(isOwn: true, isFollowing: nil)
        }
    }

    // MARK: - Comments and activity (BS-273)

    ///The post with its comments; the count on its button follows what happens there. With
    ///no comments yet the keyboard comes up, as there is nothing to read first. A reshare's
    ///comments are its own, with the original quoted above them. (BS-292)
    private func openComments(_ id: String) {
        guard let post = shownPost(id) else { return }
        let comments = CommentsController(post: post, original: post.reshareOf.flatMap { originals[$0] })
        comments.startsWriting = commentCounts[id] == 0
        comments.onCountChanged = { [weak self] count in
            guard let self, self.commentCounts[id] != count else { return }
            self.commentCounts[id] = count
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(comments, animated: true)
    }

    private func openActivity() {
        guard Auth.auth().currentUser != nil else {
            return Utilities.showAlert(on: self, title: "Sign In", message: "Sign in to see your Community activity.")
        }
        setActivityDot(false)
        navigationController?.pushViewController(ActivityController(), animated: true)
    }

    // MARK: - Navigation

    ///Search by @username. (BS-270)
    private func findPeopleTapped() {
        guard Auth.auth().currentUser != nil else {
            return Utilities.showAlert(on: self, title: "Sign In", message: "Sign in to find people in Community.")
        }
        navigationController?.pushViewController(UserSearchController(), animated: true)
    }

    ///Someone's profile; not again for the one already showing.
    private func openProfile(_ uid: String) {
        guard uid != profileUid else { return }
        navigationController?.pushViewController(CommunityController(profileOf: uid), animated: true)
    }

    ///A link in a post opens in the app, in Reader where the page allows, like a news article.
    private func openLink(_ url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        present(SFSafariViewController(url: url, configuration: config), animated: true)
    }

    ///The same chart a search result opens, loading its own price and logo. On a ticker's
    ///posts, its own $TICKER goes back to the chart it came from.
    private func openChart(_ symbol: String) {
        if symbol.uppercased() == ticker, navigationController?.viewControllers.dropLast().last is ChartController {
            navigationController?.popViewController(animated: true)
            return
        }
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else { return }
        destination.informationStockTicker = TickersCurrentValues(ticker: symbol, marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
        destination.nameTicker = symbol
        destination.imageCompany = UIImage(named: "mw-logo")
        destination.loadsQuoteAndLogo = true
        navigationController?.pushViewController(destination, animated: true)
    }
}
