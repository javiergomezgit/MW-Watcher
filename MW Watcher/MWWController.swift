//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SafariServices

class MWWController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var rssItemsImages: [RSSItemWithImages] = []
    let savedFeeds = SaveFeeds()
    let saveHeadlines = SaveHeadlines()
    var refreshControl = UIRefreshControl()
    var overlay : UIView!
    var alert : UIAlertController!
    var activityIndicator : UIActivityIndicatorView!
    var loadedTimes = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(MWWCell.nib(), forCellReuseIdentifier: MWWCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl) // not required when using UITableViewController

        loadFeeds()
        
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadFeeds()
        //tableView.reloadData()
    }
    
    
    func loadFeeds() {
        
        let mwURLString = "https://www.marketwatch.com/latest-news"
        let parsingHTML = HTMLParser()
        let rssItems = parsingHTML.loadHTML(urlString: mwURLString, amountOfFeeds: 10)
        
        if rssItems.isEmpty {
            DispatchQueue.main.async {
                self.rssItemsImages = self.savedFeeds.loadFeeds()
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        } else {
            DispatchQueue.main.async {
                self.savedFeeds.deleteFeeds()
            }
            self.rssItemsImages.removeAll()
            
            for rssItem in rssItems {
                let downloadedImage = self.downloadImageFeed(URLImage: rssItem.enclosure)
                
                self.rssItemsImages.append(
                    RSSItemWithImages(
                        title: rssItem.title,
                        link: rssItem.link,
                        pubDate: rssItem.pubDate,
                        ticker: rssItem.ticker,
                        linkTicker: rssItem.linkTicker,
                        rssImage: downloadedImage
                    )
                )
                
                DispatchQueue.main.async {
                    self.savedFeeds.saveRSS(
                        title: rssItem.title, link: rssItem.link, pubDate: rssItem.pubDate, ticker: rssItem.ticker, linkTicker: rssItem.linkTicker, image: downloadedImage
                    )
                }
            }
            self.refreshControl.endRefreshing()
            self.tableView.reloadData()
        }
    }
   
    
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage()
        if URLImage == "" {
            image = UIImage(named: "mw-logo")!
        } else {
            let url = URL(string: URLImage)
            do {
                let data = try Data(contentsOf: url!)
                let imageToCache = UIImage(data: data)!
                imageCache.setObject(imageToCache, forKey: URLImage as NSString)
                image = imageToCache
            } catch {
                image = UIImage(named: "mw-logo")!
            }
        }
        return image
    }
}


// MARK: - Table Delegate
extension MWWController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return rssItemsImages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: MWWCell.identifier, for: indexPath) as! MWWCell
        let rssItem = rssItemsImages[indexPath.row]

        cell.setRSSValues(title: rssItem.title, description: rssItem.ticker, link: rssItem.link, pubdate: rssItem.pubDate, linkTicker: rssItem.linkTicker, imageFeed: rssItem.rssImage)
        
        cell.linkTickerButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.addTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func saveTitle(sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)
        let title = self.rssItemsImages[sender.tag].title
        let netChange = self.rssItemsImages[sender.tag].ticker
        let headline = "\(netChange) | \(title)"
        let dateOfNew = self.rssItemsImages[sender.tag].pubDate
        
        print (sender.tag)
        print (headline)

        if saveHeadlines.saveHeadlines(headline: headline, date: dateOfNew) {
            let boldConfig = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
            let boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: boldConfig)
            
            sender.setImage(boldSearch, for: .normal)
            sender.tintColor = .red
            print ("\(headline) saved article")
        }
    }
    
    @objc func shareTitle(sender: UIButton){
        sender.animateButton(sender: sender, duration: 0.1)
        let index = sender.tag
        let title = self.rssItemsImages[index].title
        let netChange = self.rssItemsImages[index].ticker
        
        let objectsToShare = [netChange, " | ", title] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @objc func connected(sender: UIButton){
        guard let urlString = sender.titleLabel?.text else { return }
        guard let url = URL(string: urlString) else { return }

        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }
}


//MARK: - Button delegate
extension UIButton {
    func animateButton(sender: UIButton, duration: Double) {
        UIButton.animate(withDuration: duration,
                         animations: {
                            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                            },
                         completion: { finish in
                            UIButton.animate(withDuration: duration, animations: {
                                sender.transform = CGAffineTransform.identity
                            })
                         }
        )
   }
}
