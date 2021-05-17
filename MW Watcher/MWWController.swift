//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SSCustomPullToRefresh

class MWWController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    //var rssItems: [RSSItem] = []
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
        
        tableView.register(MWWCell.nib(), forCellReuseIdentifier: MWWCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActiveNotification(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        setUpPulseAnimation()
        
        fetchMW()
        //reloadTable()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showLoadingAlert()
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
        //fetchMW()
//        put off line then run, then put online and has to refresh
//        spinner is not refreshing
         
    }
    
    @objc func reloadTable() {
        refreshControl.beginRefreshing()
        fetchMW()
        refreshControl.endRefreshing()
    }
   
    func fetchMW(){
        let feedParser = FeedParser()
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo"
        //let mwURLString = "https://www.marketwatch.com/latest-news"

            feedParser.parseFeed(url: mwURLString) { [self] (rssItems) in
                print (rssItems)

            if rssItems.count < 10 {
                DispatchQueue.main.async {
                    self.rssItemsImages = self.savedFeeds.loadFeeds()
                }
            } else {
                DispatchQueue.main.async {
                    self.savedFeeds.deleteFeeds()
                }
                
                for rssItem in rssItems {
                    let downloadedImage = self.downloadImageFeed(URLImage: rssItem.enclosure)
                    
                    DispatchQueue.main.async {
                        self.savedFeeds.saveRSS(
                            title: rssItem.title, link: rssItem.link, pubDate: rssItem.pubDate, ticker: rssItem.ticker, linkTicker: rssItem.linkTicker, image: downloadedImage
                        )
                    }
                    
                    self.rssItemsImages.append(
                        RSSItemWithImages(
                            title: rssItem.title, link: rssItem.link, pubDate: rssItem.pubDate, ticker: rssItem.ticker, linkTicker: rssItem.linkTicker, rssImage: downloadedImage
                        )
                    )
                }
            }

            DispatchQueue.main.async {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .left)
                self.tableView.reloadData()
                print ("reload data unique")
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
        
        loadedTimes += 1
        if loadedTimes == rssItemsImages.count {
            activityIndicator.stopAnimating()
            overlay.removeFromSuperview()
            alert.dismiss(animated: true, completion: nil)
        }
        
        return cell
    }
    
    @objc func connected(sender: UIButton){
        guard let url = sender.titleLabel?.text else { return }
        
        if let url = URL(string: url) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160
    }
}


// MARK: - AnimationDelegate
extension MWWController: RefreshDelegate {
 
    func startRefresh() {
        print("start refreshing")
        fetchMW()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.spinnerAnnimation.endRefreshing()
        }
    }
    
    func endRefresh() {
        print("End Refreshing")
    }
}

