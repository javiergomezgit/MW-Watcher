//
//  TickerNewsController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/5/21.
//

import UIKit

struct TickerNews {
    let headline: String
    let pubDate: String
    let linkHeadline: String
    let author: String
    var image: UIImage //filled in after the async image download
}

class TickerNewsController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var ticker = ""
    var name = ""
    var tickerNewsArray: [TickerNews] = []
    let saveHeadlines = UserSaveNews()
    //Keyed by article link. cellForRowAt never rendered this at all, so a reused cell kept
    //whatever bookmark the previous article left on it.
    var savedLinks: Set<String> = []
    var refreshControl = UIRefreshControl()
    let child = Spinner()
    ///Says why the list is empty, in place of the alerts that closed the screen on OK: no
    ///news for the ticker, or a request that failed, with a way to try again. (BS-248)
    private lazy var emptyView = EmptyStateView(title: "", message: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading...")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        tableView.separatorStyle = .none
        installTitle()
        
        savedLinks = saveHeadlines.savedLinks()
        
        loadNews()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissController))
    }
    
    // MARK: - Title
    
    ///Ticker over name in the navigation bar, level with the close button. They were a 90 pt
    ///block of their own under an empty bar, which pushed the stories half a screen down.
    private func installTitle() {
        let tickerLabel = UILabel()
        //An index's "^" is for the server, not for people.
        tickerLabel.text = ticker.hasPrefix("^") ? String(ticker.dropFirst()) : ticker
        tickerLabel.font = UIFont(name: "Avenir-Heavy", size: 18) ?? .systemFont(ofSize: 18, weight: .heavy)
        tickerLabel.textColor = .label
        
        let nameLabel = UILabel()
        nameLabel.text = name == ticker ? nil : name
        nameLabel.isHidden = nameLabel.text?.isEmpty ?? true
        nameLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = ProfileStyle.secondaryText
        nameLabel.lineBreakMode = .byTruncatingTail
        
        let stack = UIStackView(arrangedSubviews: [tickerLabel, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        navigationItem.titleView = stack
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ProfileStyle.background
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }
    
    @objc func dismissController() {
        dismiss(animated: true)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadNews()
    }
    
    ///Stocks and crypto ask the same endpoint; they had two copies of this that differed only
    ///in their alerts.
    func loadNews() {
        startStopSpinner(start: true)
        refreshControl.beginRefreshing()
        tableView.backgroundView = nil
        
        NewsCallAPI.shared.loadStockNews(ticker: ticker, name: name) { [weak self] loadedNews in
            DispatchQueue.main.async {
                guard let self else { return }
                if loadedNews?.isEmpty == true {
                    self.loadMarketFallback()
                    return
                }
                self.setFallbackNote(visible: false)
                self.refreshControl.endRefreshing()
                self.startStopSpinner(start: false)
                //A failed refresh keeps the stories already on screen.
                if let loadedNews {
                    self.tickerNewsArray = loadedNews
                    self.tableView.reloadData()
                }
                self.updateEmptyState(failed: loadedNews == nil)
            }
        }
    }
    
    // MARK: - Market news fallback
    
    ///A symbol with no stories of its own shows the latest market news under a note saying so,
    ///rather than an empty sheet. Only when neither has anything is the empty state shown. (BS-261)
    private func loadMarketFallback() {
        NewsCallAPI.shared.loadMarketNews(section: "markets") { [weak self] items in
            let stories = Array((items ?? []).prefix(Self.fallbackCount))
            let placeholder = UIImage(named: "mw-logo") ?? UIImage()
            var urls = [Int: String]()
            let news = stories.enumerated().map { index, item in
                if let imageURL = item.imageURL { urls[index] = imageURL }
                return TickerNews(headline: item.headline, pubDate: item.pubDate,
                                  linkHeadline: item.link, author: item.author, image: placeholder)
            }
            Support.sharedSupport.fillImages(into: news, urls: urls, imagePath: \TickerNews.image) { filled in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                    self.tickerNewsArray = filled
                    self.setFallbackNote(visible: !filled.isEmpty)
                    self.tableView.reloadData()
                    self.updateEmptyState(failed: false)
                }
            }
        }
    }
    
    private static let fallbackCount = 5
    
    private func setFallbackNote(visible: Bool) {
        guard visible else {
            tableView.tableHeaderView = nil
            return
        }
        let symbol = ticker.hasPrefix("^") ? String(ticker.dropFirst()) : ticker
        let label = UILabel()
        label.text = "No recent stories for \(symbol). Here's the latest market news."
        label.numberOfLines = 0
        label.font = UIFont(name: "Avenir-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        label.textColor = ProfileStyle.secondaryText
        let width = tableView.bounds.width
        let height = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        label.frame = CGRect(x: 0, y: 0, width: width, height: height + 12)
        tableView.tableHeaderView = label
    }
    
    private func updateEmptyState(failed: Bool) {
        guard tickerNewsArray.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        if failed {
            emptyView.configure(title: "News isn't available right now",
                                message: "Check your connection and try again.",
                                actionTitle: "Try again") { [weak self] in self?.loadNews() }
        } else {
            emptyView.configure(title: "No recent news for \(ticker)",
                                message: "Stories about it will show here when there are some.")
        }
        tableView.backgroundView = emptyView
    }
    
    func startStopSpinner(start: Bool){
        if start {
            addChild(child)
            child.view.frame = view.frame
            view.addSubview(child.view)
            child.didMove(toParent: self)
        } else {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}


extension TickerNewsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickerNewsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TickerNewsCell", for: indexPath) as! TickerNewsViewCell
        
        cell.headlineLabel.text = tickerNewsArray[indexPath.row].headline
        cell.dateLabel.text = tickerNewsArray[indexPath.row].pubDate
        cell.newsImageView.image = tickerNewsArray[indexPath.row].image
        cell.authorLabel.text = tickerNewsArray[indexPath.row].author
        
        cell.linkButton.titleLabel?.text = tickerNewsArray[indexPath.row].linkHeadline
        //UIControl keeps duplicate registrations, so a reused cell fired this action once
        //per dequeue. Removing the pair first guarantees exactly one.
        cell.linkButton.removeTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        applySavedState(to: cell.saveButton, link: tickerNewsArray[indexPath.row].linkHeadline)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.removeTarget(self, action: #selector(saveHeadline(sender:)), for: .touchUpInside)
        cell.saveButton.addTarget(self, action: #selector(saveHeadline(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.removeTarget(self, action: #selector(shareHeadline(sender:)), for: .touchUpInside)
        cell.shareButton.addTarget(self, action: #selector(shareHeadline(sender:)), for: .touchUpInside)
        
        return cell
    }
    @objc func shareHeadline(sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)
        
        let newsItem = self.tickerNewsArray[sender.tag]
        let headline = newsItem.headline
        let date = newsItem.pubDate
        let author = newsItem.author
        let link = newsItem.linkHeadline
        let image = newsItem.image
        
        let formattedText = """
        📰 \(headline)
        📅 \(date)
        👤 Source: \(author)
        🔗 Read more: \(link)
        Shared via Bullis Square 📱
        """
        
        var activityItems: [Any] = [formattedText]
        if image.size.width > 1 && image.size.height > 1 {
            activityItems.append(image)
        } else {
            activityItems.append(UIImage(named: "mw-logo")!)
        }
        
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    
    @objc func saveHeadline(sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)
        guard sender.tag < tickerNewsArray.count else { return }
        let newsItem = tickerNewsArray[sender.tag]
        let link = newsItem.linkHeadline
        
        //Save-or-unsave used to be decided by comparing the PNG bytes of the button's own
        //image, which made the button the source of truth. Ask the store instead.
        if savedLinks.contains(link) {
            if saveHeadlines.deleteNews(link: link, deleteAll: false) {
                savedLinks.remove(link)
            } else {
                print ("\(newsItem.headline) NOT UNSAVED")
            }
        } else {
            if saveHeadlines.saveNews(headline: newsItem.headline, date: newsItem.pubDate, link: link, author: newsItem.author, imageNews: newsItem.image) {
                savedLinks.insert(link)
                print ("\(newsItem.headline) saved article")
            } else {
                //TODO: - send alert to user that was not possible to save
                print ("\(newsItem.headline) NOT SAVED")
            }
        }
        
        applySavedState(to: sender, link: link)
    }
    
    //One place decides how a bookmark looks, so a tap and a redraw cannot disagree. The
    //unsave path used to tint the button .darkGray, which reads as gone against the dark
    //background.
    private func applySavedState(to button: UIButton, link: String) {
        //No explicit SymbolConfiguration. The storyboard sets this button's
        //preferredSymbolConfiguration (large scale, regular weight) and that is what sized
        //the bookmark before; building one here would change how it draws.
        let symbol = savedLinks.contains(link) ? "bookmark.fill" : "bookmark"
        button.tintColor = UIColor(named: "colorHightlight")
        button.setImage(UIImage(systemName: symbol), for: .normal)
    }

    @objc func connected(sender: UIButton){
        guard let urlString = sender.titleLabel?.text else { return }
        guard let url = URL(string: urlString) else { return }
        
        UIApplication.shared.open(url)
    }
    
}
