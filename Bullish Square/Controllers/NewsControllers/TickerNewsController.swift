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
    
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var nameStock: UILabel!
    
    var ticker = ""
    var name = ""
    var cryptoCoin = false
    var tickerNewsArray: [TickerNews] = []
    let saveHeadlines = UserSaveNews()
    //Keyed by article link. cellForRowAt never rendered this at all, so a reused cell kept
    //whatever bookmark the previous article left on it.
    var savedLinks: Set<String> = []
    var refreshControl = UIRefreshControl()
    var notFound = false
    let child = Spinner()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading...")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        tickerLabel.text = ticker
        nameStock.text = name
        
        savedLinks = saveHeadlines.savedLinks()
        
        if cryptoCoin {
            loadCryptoNews()
        } else {
            loadTickerNews()
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissController))
    }
    
    @objc func dismissController() {
        dismiss(animated: true)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        if cryptoCoin {
            loadCryptoNews()
        } else {
            loadTickerNews()
        }    }
    

    func loadCryptoNews() {
        startStopSpinner(start: true)
        refreshControl.beginRefreshing()

        NewsCallAPI.shared.loadStockNews(ticker: ticker, name: self.name) { loadedCryptoNewsArray in
            if loadedCryptoNewsArray != nil && loadedCryptoNewsArray?.count != 0{
                self.tickerNewsArray = loadedCryptoNewsArray!
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                }
            } else {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                    self.notFound = true
                    
                    // Create custom alert with completion handler
                    let alertController = UIAlertController(title: "Error", message: "We couldn't find any news about it", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                        self.dismiss(animated: true, completion: nil)
                    }
                    alertController.addAction(okAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    func loadTickerNews() {
        startStopSpinner(start: true)
        refreshControl.beginRefreshing()

        NewsCallAPI.shared.loadStockNews(ticker: ticker, name: self.name) { loadedNewsArray in
            if loadedNewsArray != nil {
                self.tickerNewsArray = loadedNewsArray!
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        self.refreshControl.endRefreshing()
                        self.startStopSpinner(start: false)
                    }
                if loadedNewsArray?.count == 0 {
                    DispatchQueue.main.async {
                        self.startStopSpinner(start: false)
                        self.notFound = true
                        
                        // Create custom alert with completion handler
                        let alertController = UIAlertController(title: "Warning", message: "Didn't find any related news", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                            self.dismiss(animated: true, completion: nil)
                        }
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                    self.notFound = true
                    
                    // Create custom alert with completion handler
                    let alertController = UIAlertController(title: "Error", message: "Didn't find any related news", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                        self.dismiss(animated: true, completion: nil)
                    }
                    alertController.addAction(okAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
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
        tickerLabel.text = ticker
        
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
