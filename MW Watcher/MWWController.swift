//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import SSCustomPullToRefresh

class MWWController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var rssItems: [RSSItem] = []
    var refreshControl = UIRefreshControl()
    var tickerExists = false
    
    var spinnerAnnimation: SpinnerAnimationView!
    
    //test overlay
    var overlayView : UIView!
    var overlay : UIView!
    var alert : UIAlertController!
    var activityIndicator : UIActivityIndicatorView!

    var loadedTimes = 0
    
    override func viewDidLoad() {
        super.viewDidLoad() //FIRST
        
        //showLoadingAlert()

        
        tableView.register(MWWCell.nib(), forCellReuseIdentifier: MWWCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        NotificationCenter.default.addObserver(self,
                                                  selector: #selector(handleAppDidBecomeActiveNotification(notification:)),
                                                  name: UIApplication.didBecomeActiveNotification,
                                                  object: nil)
        
        setUpPulseAnimation()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showLoadingAlert()
    }
    
    
    
    override func viewWillLayoutSubviews() {
        //showLoadingAlert() //SIX
    }
    
    override func viewDidLayoutSubviews() {
        //showLoadingAlert()
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        //showLoadingAlert()
    }
    
    

    func showLoadingAlert() {
        
//        self.overlayView = UIView()
//        self.activityIndicator = UIActivityIndicatorView()
//
//        overlayView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
//        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.7)
//        overlayView.clipsToBounds = true
//        overlayView.layer.cornerRadius = 10
//        overlayView.layer.zPosition = 1
//
//        activityIndicator.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
//        activityIndicator.center = CGPoint(x: overlayView.bounds.width / 2, y: overlayView.bounds.height / 2)
//        activityIndicator.style = .large
//        overlayView.addSubview(activityIndicator)
//
//        overlayView.center = view.center
//                view.addSubview(overlayView)
//                activityIndicator.startAnimating()
        
        
        overlay = UIView(frame: view.frame)
        overlay!.backgroundColor = UIColor.systemBlue
        overlay!.alpha = 0.6
        

        view.addSubview(overlay!)


        alert = UIAlertController(title: nil, message: "Please wait, download news... ", preferredStyle: .alert)
        
        
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: (self.view.frame.width / 2)-100, y: 50, width: 100, height: 100))
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = UIColor.cyan
        activityIndicator.style = UIActivityIndicatorView.Style.large
        activityIndicator.startAnimating();

        alert.view.addSubview(activityIndicator)
        present(alert, animated: true, completion: nil)
    }
    
    
    func setUpPulseAnimation() {
//SECOND
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
//FOUR        setUpPulseAnimation()
        fetchMW()
    }
    
    @objc func reloadTable() {
        refreshControl.beginRefreshing()
        fetchMW()
        refreshControl.endRefreshing()
    }
   
    func fetchMW(){
        //let mwURLStringRealTime = "http://feeds.marketwatch.com/marketwatch/realtimeheadlines"
        //https://developer.apple.com/news/rss/news.rss
        //let mwURLString = "http://feeds.marketwatch.com/marketwatch/topstories/"
        //let mwURLString = "https://rss.app/feeds/9QXMh4Scbqf6dINi.xml"
        //let mwURLString = "https://politepol.com/fd/bXcf1FENvIgK"
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images
        
        let feedParser = FeedParser() //FIVE
        feedParser.parseFeed(url: mwURLString) { (rssItems) in
            self.rssItems = rssItems

            DispatchQueue.main.async {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .left)
                self.tableView.reloadData()
                print ("reload data unique")
            }
        }
    }
}

let imageCache = NSCache<NSString, UIImage>()

extension MWWController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return rssItems.count //THIRD
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: MWWCell.identifier, for: indexPath) as! MWWCell
        let rssItem = rssItems[indexPath.row]

        var downloadedImage = UIImage()

        downloadedImage = self.downloadImageFeed(URLImage: rssItem.enclosure)
                
        cell.setRSSValues(title: rssItem.title, description: rssItem.ticker, link: rssItem.link, pubdate: rssItem.pubDate, linkTicker: rssItem.linkTicker, imageFeed: downloadedImage)
        
        if rssItem.linkTicker == "" {
            tickerExists = false
        } else {
            tickerExists = true
        }
        
        cell.linkTickerButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        return cell
    }
        
    func downloadImageFeed(URLImage: String) -> UIImage {
        
        print ("download image")

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
        loadedTimes += 1
        
        if loadedTimes == rssItems.count {

            activityIndicator.stopAnimating()
            overlay.removeFromSuperview()
            alert.dismiss(animated: true, completion: nil)
            
        }
        
        return image
    }
    
    @objc func connected(sender: UIButton){
        guard let url = sender.titleLabel?.text else { return }
        
        if let url = URL(string: url) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if tickerExists {
//            return 90
//        }
        return 160
    }
    
    
  }


// MARK: - AnimationDelegate
extension MWWController: RefreshDelegate {
 
    func startRefresh() {
        print("start refreshing")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.spinnerAnnimation.endRefreshing()
        }
    }
    
    func endRefresh() {
        print("End Refreshing")
    }
    
}
