//
//  SavedHeadlinesController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/24/21.
//


import UIKit
import AMPopTip
import SafariServices

///The stories saved from Live News, as a compact reading list, most recently saved first.
///Tapping a row opens the story in the app; swiping deletes it. The ElevenLabs "read aloud"
///button that used to sit on each row was removed, along with its request and player.
class SavedNewsController: UIViewController {

    @IBOutlet var tableView: UITableView!

    let savedNews = UserSaveNews()
    var newsItems: [UserSavedNewsItem] = []
    var alreadyLaunched = false
    private let imageDeleteAllNavBar = UIImageView(image: UIImage(systemName: "trash.circle.fill"))

    ///Thumbnails decoded at row size, by article link. Saved pictures can be full-size PNGs
    ///(stories saved before BS-234 were not shrunk), so they are never decoded whole.
    private var thumbnails: [String: UIImage] = [:]
    private let thumbnailQueue = DispatchQueue(label: "com.bullishsquare.savednews.thumbnails", qos: .userInitiated)

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No saved stories yet.\nTap the bookmark on any story in Live News to keep it here."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor(named: "colorSecondary")
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()

        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingSavedNews")
        UserDefaults.standard.set(true, forKey: "firstLaunchingSavedNews")
        alreadyLaunched = isFirstLaunch

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SavedNewsCompactCell.self, forCellReuseIdentifier: SavedNewsCompactCell.reuseIdentifier)
        //The storyboard's table predates the compact rows: fixed 120 pt rows and no selection.
        tableView.allowsSelection = true
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
        reload()

        if !alreadyLaunched, !newsItems.isEmpty {
            alreadyLaunched = true
            showSwipeHint()
        }
    }

    ///Re-read on every appearance: stories are saved from Live News while this screen is away.
    private func reload() {
        newsItems = savedNews.loadNews()
        let links = Set(newsItems.map(\.link))
        thumbnails = thumbnails.filter { links.contains($0.key) }
        tableView.backgroundView = newsItems.isEmpty ? emptyStateLabel : nil
        tableView.reloadData()
    }

    private func showSwipeHint() {
        guard let firstRow = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) else { return }
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(4)
        popTip.bubbleColor = UIColor(named: "onboardingNotification") ?? .systemBlue
        popTip.shouldDismissOnTap = true
        let frame = firstRow.convert(firstRow.bounds, to: view)
        popTip.show(text: "Swipe left to delete", direction: .down, maxWidth: 160, in: view, from: frame)
    }
}


extension SavedNewsController: UITableViewDelegate, UITableViewDataSource, SFSafariViewControllerDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SavedNewsCompactCell.reuseIdentifier, for: indexPath) as! SavedNewsCompactCell
        let item = newsItems[indexPath.row]

        cell.configure(headline: item.headline, source: item.author, date: item.pubDate, thumbnail: thumbnails[item.link])
        if thumbnails[item.link] == nil {
            loadThumbnail(for: item)
        }

        //UIControl keeps duplicate registrations, so a reused cell fired this action once
        //per dequeue. Removing the pair first guarantees exactly one.
        cell.shareButton.removeTarget(self, action: #selector(shareHeadline(_:)), for: .touchUpInside)
        cell.shareButton.addTarget(self, action: #selector(shareHeadline(_:)), for: .touchUpInside)

        return cell
    }

    ///Decodes the saved picture at row size off the main thread, then fills whichever row now
    ///shows that story. Keyed by link: a delete moves rows while it decodes.
    private func loadThumbnail(for item: UserSavedNewsItem) {
        let link = item.link
        let data = item.newsImageData
        let pixels = Int(SavedNewsCompactCell.thumbnailSide * UIScreen.main.scale)
        thumbnailQueue.async { [weak self] in
            let image = Support.downsampledImage(from: data, maxPixelSize: pixels) ?? UIImage(named: "mw-logo")
            DispatchQueue.main.async {
                guard let self, let image else { return }
                self.thumbnails[link] = image
                guard let row = self.newsItems.firstIndex(where: { $0.link == link }),
                      let cell = self.tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? SavedNewsCompactCell else { return }
                cell.thumbnailView.image = image
            }
        }
    }

    //Opens in the app, as Live News does, rather than switching to Safari.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let url = URL(string: newsItems[indexPath.row].link) else { return }
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true
        let safari = SFSafariViewController(url: url, configuration: configuration)
        safari.delegate = self
        present(safari, animated: true)
    }

    @objc func shareHeadline(_ sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)

        //Resolved at tap time: a row index stored on the button goes stale after a delete.
        let point = sender.convert(CGPoint.zero, to: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point), indexPath.row < newsItems.count else { return }
        let newsItem = newsItems[indexPath.row]

        let formattedText = """

         📰 \(newsItem.headline)

         📅 \(newsItem.pubDate)
         👤 Source: \(newsItem.author)

         🔗 Read more: \(newsItem.link)

         Shared via Bullish Square 📱
         """

        var activityItems: [Any] = [formattedText]
        //Shared at a sensible size; the saved picture can be a camera original.
        if let image = Support.downsampledImage(from: newsItem.newsImageData), image.size.width > 1, image.size.height > 1 {
            activityItems.append(image)
        } else if let logo = UIImage(named: "mw-logo") {
            activityItems.append(logo)
        }

        let activityVC = PostToCommunity.shareSheet(items: activityItems, headline: newsItem.headline,
                                                    link: newsItem.link, from: self)
        present(activityVC, animated: true)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let link = newsItems[indexPath.row].link
            _ = savedNews.deleteNews(link: link, deleteAll: false)
            newsItems.remove(at: indexPath.row)
            thumbnails[link] = nil
            tableView.deleteRows(at: [indexPath], with: .left)
            tableView.backgroundView = newsItems.isEmpty ? emptyStateLabel : nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView() // Empty view for transparent spacing
    }
}

//MARK: Right top button in navigation controller
extension SavedNewsController {
    private struct Const {
        /// Image height/width for Large NavBar state
        static let ImageSizeForLargeState: CGFloat = 36
        /// Image height/width for Small NavBar state
        static let ImageSizeForSmallState: CGFloat = 28

        /// Height of NavBar for Small state. Usually it's just 44
        static let NavBarHeightSmallState: CGFloat = 44
        /// Height of NavBar for Large state. Usually it's just 96.5 but if you have a custom font for the title, please make sure to edit this value since it changes the height for Large state of NavBar
        static let NavBarHeightLargeState: CGFloat = 96.5


        /// Margin from right anchor of safe area to right anchor of Image
        static let ImageRightMargin: CGFloat = 24

        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Large NavBar state
        static let ImageBottomMarginForLargeState: CGFloat = 14
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Small NavBar state
        static let ImageBottomMarginForSmallState: CGFloat = 0


    }

    private func setupUI() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        imageDeleteAllNavBar.isUserInteractionEnabled = true
        imageDeleteAllNavBar.tintColor = UIColor(named: "colorSecondary")
        imageDeleteAllNavBar.addGestureRecognizer(tapGestureRecognizer)
        imageDeleteAllNavBar.accessibilityLabel = "Delete all saved stories"
        imageDeleteAllNavBar.accessibilityTraits = .button
        imageDeleteAllNavBar.isAccessibilityElement = true

        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageDeleteAllNavBar)
        imageDeleteAllNavBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageDeleteAllNavBar.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -Const.ImageRightMargin),
            imageDeleteAllNavBar.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageDeleteAllNavBar.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageDeleteAllNavBar.widthAnchor.constraint(equalTo: imageDeleteAllNavBar.heightAnchor)
        ])
    }

    ///Asks first. One tap used to wipe every saved story, with no way back.
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)  {
        guard !newsItems.isEmpty else { return }
        let count = newsItems.count
        let alert = UIAlertController(title: "Delete all saved stories?",
                                      message: "\(count) \(count == 1 ? "story" : "stories") will be removed. This can't be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            guard let self else { return }
            _ = self.savedNews.deleteNews(link: "", deleteAll: true)
            self.reload()
        })
        present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
    }

    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageDeleteAllNavBar.alpha = show ? 1.0 : 0.0
        }
    }
}
