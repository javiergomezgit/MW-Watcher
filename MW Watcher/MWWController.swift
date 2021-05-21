//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SSCustomPullToRefresh
import SafariServices

class MWWController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var rssItemsImages: [RSSItemWithImages] = []
    let savedFeeds = SaveFeeds()

    var refreshControl = UIRefreshControl()
    var spinnerAnnimation: SpinnerAnimationView!
    var overlay : UIView!
    var alert : UIAlertController!
    var activityIndicator : UIActivityIndicatorView!
    var loadedTimes = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Market News Watcher"

        //self.navigationController!.navigationBar.barStyle = UIBarStyle.black
        self.navigationController!.navigationBar.isTranslucent = true
        //self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationController!.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.black]

        tableView.register(MWWCell.nib(), forCellReuseIdentifier: MWWCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActiveNotification(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        setUpPulseAnimation()
        loadFeeds()
    }
    
    func showLoadingAlert() {
     
        overlay = UIView(frame: view.frame)
        overlay!.backgroundColor = UIColor.systemBlue
        overlay!.alpha = 0.6
        view.addSubview(overlay!)

        alert = UIAlertController(title: nil, message: "Please wait, downloading news... ", preferredStyle: .alert)
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: (self.view.frame.width / 2)-100, y: 50, width: 100, height: 100))
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = UIColor.cyan
        activityIndicator.style = UIActivityIndicatorView.Style.large
        activityIndicator.startAnimating();
        alert.view.addSubview(activityIndicator)
        present(alert, animated: true, completion: nil)
        
        /* Stop animation
         activityIndicator.stopAnimating()
         overlay.removeFromSuperview()
         alert.dismiss(animated: true, completion: nil)
         */
    }
    
    func setUpPulseAnimation() {
        if self.traitCollection.userInterfaceStyle == .dark {
            spinnerAnnimation = SpinnerAnimationView(image: UIImage(named: "spinner")!, backgroundColor: .black)
        } else {
            spinnerAnnimation = SpinnerAnimationView(image: UIImage(named: "spinner")!, backgroundColor: .white)
        }
        spinnerAnnimation.delegate = self
        spinnerAnnimation.parentView = self.tableView
        spinnerAnnimation.setupRefreshControl()
    }
    
    
    @objc func handleAppDidBecomeActiveNotification(notification: Notification) {
        //loadFeeds()
    }

    func loadFeeds() {
        
        let mwURLString = "https://www.marketwatch.com/latest-news"
        let parsingHTML = HTMLParser()
        let rssItems = parsingHTML.loadHTML(urlString: mwURLString, amountOfFeeds: 10)
        
        if rssItems.isEmpty {
            DispatchQueue.main.async {
                self.rssItemsImages = self.savedFeeds.loadFeeds()
                self.tableView.reloadData()
            }
        } else {
            DispatchQueue.main.async {
                self.savedFeeds.deleteFeeds()
            }
            
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
        
        return cell
    }
    
    @objc func connected(sender: UIButton){
        guard let urlString = sender.titleLabel?.text else { return }
        guard let url = URL(string: urlString) else { return }

        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }
}


// MARK: - AnimationDelegate
extension MWWController: RefreshDelegate {
 
    func startRefresh() {
        print("start refreshing")
        loadFeeds()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.spinnerAnnimation.endRefreshing()
        }
    }
    
    func endRefresh() {
        print("End Refreshing")
    }
}

