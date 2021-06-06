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

        loadNews()
        
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadNews()
        //tableView.reloadData()
    }
    

    
    func loadNews(){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url: NSURL(string: "https://bing-news-search1.p.rapidapi.com/news?safeSearch=Off&category=Business")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error)
            } else {
                let httpResponse = response as? HTTPURLResponse
                //print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                //print (json!)
                
                let jsonNews = json!["value"] as! [Any]
                
                self.rssItemsImages.removeAll()
                
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let pubDate = dictionaryNew["datePublished"] as! String
                    
                    let headline = dictionaryNew["name"] as! String
                    
                    let link = dictionaryNew["url"] as! String
                    
                    print (dictionaryNew)
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]
                    print (imageDictionary)
                    
                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        //print (imageJSON)
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = self.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let rssitem = RSSItemWithImages.init(title: headline, link: link, pubDate: pubDate, ticker: author, linkTicker: "", rssImage: downloadedImage)
                    self.rssItemsImages.append(rssitem)
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                }
                
            }
        })
        dataTask.resume()
    }

    
    
//    func loadFeeds() {
//
//        let mwURLString = "https://www.marketwatch.com/latest-news"
//        let parsingHTML = HTMLParser()
//        let rssItems = parsingHTML.loadHTML(urlString: mwURLString, amountOfFeeds: 10)
//
//        if rssItems.isEmpty {
//            DispatchQueue.main.async {
//                self.rssItemsImages = self.savedFeeds.loadFeeds()
//                self.tableView.reloadData()
//                self.refreshControl.endRefreshing()
//            }
//        } else {
//            DispatchQueue.main.async {
//                self.savedFeeds.deleteFeeds()
//            }
//            self.rssItemsImages.removeAll()
//
//            for rssItem in rssItems {
//                let downloadedImage = self.downloadImageFeed(URLImage: rssItem.enclosure)
//
//                self.rssItemsImages.append(
//                    RSSItemWithImages(
//                        title: rssItem.title,
//                        link: rssItem.link,
//                        pubDate: rssItem.pubDate,
//                        ticker: rssItem.ticker,
//                        linkTicker: rssItem.linkTicker,
//                        rssImage: downloadedImage
//                    )
//                )
//
//                DispatchQueue.main.async {
//                    self.savedFeeds.saveRSS(
//                        title: rssItem.title, link: rssItem.link, pubDate: rssItem.pubDate, ticker: rssItem.ticker, linkTicker: rssItem.linkTicker, image: downloadedImage
//                    )
//                }
//            }
//            self.refreshControl.endRefreshing()
//            self.tableView.reloadData()
//        }
//    }
   
    
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage()
        let url = URL(string: URLImage)
        do {
            let data = try Data(contentsOf: url!)
            let imageToCache = UIImage(data: data)!
            imageCache.setObject(imageToCache, forKey: URLImage as NSString)
            image = imageToCache
        } catch {
            image = UIImage(named: "mw-logo")!
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

        cell.setRSSValues(title: rssItem.title, description: rssItem.ticker, link: rssItem.link, pubdate: rssItem.pubDate, ticker: rssItem.ticker, imageFeed: rssItem.rssImage)
        
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
        let link = self.rssItemsImages[sender.tag].link
        
        print (sender.tag)
        print (headline)

        if saveHeadlines.saveHeadlines(headline: headline, date: dateOfNew, link: link) {
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
        let link = self.rssItemsImages[index].link
        
        let objectsToShare = [title, link] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @objc func connected(sender: UIButton){
        guard let urlString = sender.titleLabel?.text else { return }
        guard let url = URL(string: urlString) else { return }
        
        UIApplication.shared.open(url)

//        let vc = SFSafariViewController(url: url)
//        present(vc, animated: true)
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
