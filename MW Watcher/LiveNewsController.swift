//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SafariServices
import AMPopTip

class LiveNewsController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var newsItems: [NewsItem] = []
    let savedFeeds = SystemSaveNews()
    let saveHeadlines = UserSaveNews()
    var refreshControl = UIRefreshControl()
    var overlay : UIView!
    var alert : UIAlertController!
    var activityIndicator : UIActivityIndicatorView!
    var loadedTimes = 0
    var alreadyLaunched = false
    var savedRows : [Int: Bool] = [:]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingLiveNews")
        UserDefaults.standard.set(true, forKey: "firstLaunchingLiveNews")
        UserDefaults.standard.synchronize()
        
        //change to true for testing
        if !isFirstLaunch {
            alreadyLaunched = false
        } else {
            alreadyLaunched = true
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        loadNews()
        
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadNews()
    }
    
    
    func showFirstTimeNotification(whereView: UIView) {
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX - 50, y: whereView.frame.minY - 20, width: 100, height: 100)
        popTip.show(text: "You can save your favorite news", direction: .left, maxWidth: 150, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
        
        popTip.shouldDismissOnTap = true
        
        popTip.tapHandler = { popTip in
            print("tapped")
            //NO MORE new notification
        }
        
        
        
        popTip.dismissHandler = { popTip in
            print("dismissed")
        }
        
        popTip.tapOutsideHandler = { _ in
            print("tap outside")
        }
        
        
    }
    
    
    func loadNews(){
        
        StocksAPI.shared.loadAllNews { allNews in
            if allNews == nil {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error, try later!", titleButton: "OK", over: self)
            } else {
                self.newsItems = allNews!
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    if !self.alreadyLaunched {
                        self.showFirstTimeNotification(whereView: self.tableView)
                    }
                }
                
            }
        }
    }
}




/*
 func PDTForamte(endTime: String) -> String{
 // create dateFormatter with UTC time format
 let dateFormatter = DateFormatter()
 dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+zzzz"
 dateFormatter.timeZone = TimeZone(identifier: "UTC")
 
 guard let date = dateFormatter.date(from: endTime) else {
 return endTime.components(separatedBy: "T").first ?? "" //return date before 'T'.
 }
 
 let pdtFormatter = DateFormatter()
 pdtFormatter.dateStyle = .long
 pdtFormatter.timeStyle = .long
 if let americaZone = NSTimeZone(name: "America/Los_Angeles") {
 pdtFormatter.timeZone = americaZone as TimeZone
 }
 
 let dateString: String = pdtFormatter.string(from: date)
 
 let calendar = NSCalendar.autoupdatingCurrent
 //We subtract 1 min because American Date here be 12:00:00 AM but It should be return to the previous day
 let newDate = calendar.date(byAdding: .minute, value: -1, to: pdtFormatter.date(from: dateString)!) ?? Date()
 pdtFormatter.dateFormat = "yyyy-MM-dd"
 let newDateString: String = pdtFormatter.string(from: newDate)
 
 return newDateString
 }
 */


// MARK: - Table Delegate
extension LiveNewsController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "LiveNewsViewCell", for: indexPath) as! LiveNewsViewCell
        let newsItem = newsItems[indexPath.row]
        
        cell.setNewsValues(headline: newsItem.headline, link: newsItem.link, pubdate: newsItem.pubDate, author: newsItem.author, imageFeed: newsItem.image)
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .regular)
        if savedRows[indexPath.row] == true {
            cell.saveButton.tintColor = .red
            cell.saveButton.setImage(UIImage(systemName: "bookmark.fill", withConfiguration: configuration), for: .normal)
        } else {
            cell.saveButton.tintColor = .darkGray
            cell.saveButton.setImage(UIImage(systemName: "bookmark", withConfiguration: configuration), for: .normal)
        }
        
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.addTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func saveTitle(sender: UIButton) {
        
        sender.animateButton(sender: sender, duration: 0.1)
        let headline = self.newsItems[sender.tag].headline
        let dateOfNew = self.newsItems[sender.tag].pubDate
        let link = self.newsItems[sender.tag].link
        
        let configurationButton = sender.currentImage?.configuration //UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
        var boldSearch = UIImage()
        
        let currentImageData = sender.currentImage
        let imageData = UIImage(systemName: "bookmark", withConfiguration: configurationButton)
        
        if currentImageData?.pngData() == imageData?.pngData() {
            if saveHeadlines.saveNews(headline: headline, date: dateOfNew, link: link) {
                sender.tintColor = .red
                boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: configurationButton)!
                print ("\(headline) saved article")
                self.savedRows[sender.tag] = true
            } else {
                //TODO: - send alert to user that was not possible to save
                print ("\(headline) NOT SAVED")
            }
        } else {
            //unsave
            if saveHeadlines.deleteNews(headline: headline, date: dateOfNew, deleteAll: false)! {
                sender.tintColor = .darkGray
                boldSearch = UIImage(systemName: "bookmark", withConfiguration: configurationButton)!
                self.savedRows[sender.tag] = false
            } else {
                print ("\(headline) NOT UNSAVED")
            }
        }
        sender.setImage(boldSearch, for: .normal)
    }
    
    @objc func shareTitle(sender: UIButton){
        sender.animateButton(sender: sender, duration: 0.1)
        let index = sender.tag
        let headline = self.newsItems[index].headline
        let link = self.newsItems[index].link
        
        let objectsToShare = [headline, link] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @objc func connected(sender: UIButton){
        guard let urlString = sender.titleLabel?.text else { return }
        guard let url = URL(string: urlString) else { return }
        
        UIApplication.shared.open(url)
    }
}



