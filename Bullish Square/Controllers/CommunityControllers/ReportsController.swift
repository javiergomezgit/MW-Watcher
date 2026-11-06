//
//  ReportsController.swift
//  Bullish Square
//

import UIKit

///Open reports for an admin, newest first: why, who reported whom, and what was reported.
///Tapping one offers to open the post, remove what was reported, or dismiss the report.
///Replaces checking `reports` in the Firebase console. Only an account with the `admin`
///claim sees the button, and only it may read reports. (BS-273)
final class ReportsController: UITableViewController {

    // MARK: - Properties

    private var reports: [CommunityStore.Report] = []
    ///What each report points at, read once each: the comment's or post's text.
    private var excerpts: [String: String] = [:]
    private lazy var emptyView = EmptyStateView(title: "", message: "")
    private let store = CommunityStore.shared

    init() {
        super.init(style: .insetGrouped)
        title = "Reports"
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ReportCell")
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)
        load()
    }

    private func load() {
        store.openReports { [weak self] result in
            guard let self else { return }
            guard case .success(let reports) = result else { return self.show([], failed: true) }
            let people = reports.flatMap { [$0.reporterUid, $0.userUid] }
            let group = DispatchGroup()
            group.enter()
            AuthorDirectory.shared.load(people) { group.leave() }
            for report in reports where self.excerpts[report.id] == nil {
                group.enter()
                self.readExcerpt(report) { text in
                    self.excerpts[report.id] = text
                    group.leave()
                }
            }
            group.notify(queue: .main) { self.show(reports, failed: false) }
        }
    }

    ///The reported comment's or post's text, or a note that it is gone or was a profile.
    private func readExcerpt(_ report: CommunityStore.Report, completion: @escaping (String) -> Void) {
        if let commentId = report.commentId {
            return store.comment(id: commentId) { completion($0.map { "Comment: \($0.text)" } ?? "Comment already deleted") }
        }
        guard let postId = report.postId else { return completion("The account") }
        store.post(id: postId) { post in
            guard let post else { return completion("Post already deleted") }
            completion(post.text.isEmpty ? "Post with photos only" : "Post: \(post.text)")
        }
    }

    private func show(_ reports: [CommunityStore.Report], failed: Bool) {
        self.reports = reports
        refreshControl?.endRefreshing()
        tableView.reloadData()
        guard reports.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "Reports couldn't be loaded",
                                message: "This account may not be an admin, or the connection failed.",
                                actionTitle: "Try again") { [weak self] in self?.load() }
        } else {
            emptyView.configure(title: "No open reports", message: "Reports people send appear here.")
        }
        tableView.backgroundView = emptyView
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        reports.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReportCell", for: indexPath)
        let report = reports[indexPath.row]
        let directory = AuthorDirectory.shared
        var content = UIListContentConfiguration.subtitleCell()
        content.text = "\(report.reason?.title ?? "Report") · \(PostCell.age(of: report.createdAt))"
        content.secondaryText = "\(directory.handle(report.reporterUid)) reported \(directory.handle(report.userUid))\n"
            + (excerpts[report.id] ?? "")
        content.secondaryTextProperties.numberOfLines = 4
        ProfileStyle.style(&content)
        cell.contentConfiguration = content
        ProfileStyle.style(cell)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let report = reports[indexPath.row]
        let sheet = UIAlertController(title: report.reason?.title, message: excerpts[report.id], preferredStyle: .actionSheet)
        if let postId = report.postId {
            sheet.addAction(UIAlertAction(title: "Open Post", style: .default) { [weak self] _ in self?.openPost(postId) })
        }
        sheet.addAction(UIAlertAction(title: "Open \(AuthorDirectory.shared.handle(report.userUid))", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(CommunityController(profileOf: report.userUid), animated: true)
        })
        if report.postId != nil || report.commentId != nil {
            sheet.addAction(UIAlertAction(title: report.commentId != nil ? "Remove Comment" : "Remove Post", style: .destructive) { [weak self] _ in
                self?.act(report, remove: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "Dismiss Report", style: .default) { [weak self] _ in
            self?.act(report, remove: false)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath) ?? view
        present(sheet, animated: true)
    }

    // MARK: - Actions

    private func openPost(_ postId: String) {
        store.post(id: postId) { [weak self] post in
            guard let self else { return }
            guard let post else {
                return Utilities.showAlert(on: self, title: "Post Unavailable", message: "This post was already deleted.")
            }
            self.navigationController?.pushViewController(CommentsController(post: post), animated: true)
        }
    }

    ///Removes what was reported and closes the report, or just closes it.
    private func act(_ report: CommunityStore.Report, remove: Bool) {
        let done: (Error?) -> Void = { [weak self] error in
            guard let self else { return }
            if let error {
                return Utilities.showAlert(on: self, title: "Can't Update Report", message: error.localizedDescription)
            }
            self.reports.removeAll { $0.id == report.id }
            self.show(self.reports, failed: false)
        }
        remove ? store.removeReportedContent(report, completion: done) : store.dismissReport(report, completion: done)
    }
}
