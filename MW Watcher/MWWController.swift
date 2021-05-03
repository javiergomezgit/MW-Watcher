//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit

class MWWController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var rssItems: [RSSItem] = []
    var refreshControl = UIRefreshControl()
    var tickerExists = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(MWWCell.nib(), forCellReuseIdentifier: MWWCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        fetchMW()
        
        refreshControl.addTarget(self, action: #selector(reloadTable), for: .valueChanged)
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")

        tableView.refreshControl = refreshControl
    }
    
    @objc func reloadTable() {
        //refreshControl.beginRefreshing()
        OperationQueue.main.addOperation {
            
            self.fetchMW()
            
            self.tableView.reloadSections(IndexSet(integer: 0), with: .left)
            self.tableView.reloadData()
        }
        
        refreshControl.endRefreshing()
        print ("reloaded")
    }
   
    func fetchMW(){
        //let mwURLStringRealTime = "http://feeds.marketwatch.com/marketwatch/realtimeheadlines"
        //https://developer.apple.com/news/rss/news.rss
        //let mwURLString = "http://feeds.marketwatch.com/marketwatch/topstories/"
        //let mwURLString = "https://rss.app/feeds/9QXMh4Scbqf6dINi.xml"
        //let mwURLString = "https://politepol.com/fd/bXcf1FENvIgK"
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images

        
        let feedParser = FeedParser()
        feedParser.parseFeed(url: mwURLString) { (rssItems) in
            self.rssItems = rssItems

            OperationQueue.main.addOperation {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .left)
                self.tableView.reloadData()
            }
        }
    }
}


extension MWWController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rssItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: MWWCell.identifier, for: indexPath) as! MWWCell
        let rssItem = rssItems[indexPath.row]
        
        let downloadedImage = downloadImageFeed(URLImage: rssItem.enclosure)
        
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
        var image = UIImage()
        
        if URLImage == "" {
            image = UIImage(named: "mw-logo")!
        } else {
            let url = URL(string: URLImage)
            do {
                let data = try Data(contentsOf: url!)
                image = UIImage(data: data)!
            } catch {
                image = UIImage(named: "mw-logo")!
            }
            //let data = try? Data(contentsOf: url!) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
            //let img = UIImage(data: data!)
            //image = img!
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
        return 158
    }
    
    
  }
