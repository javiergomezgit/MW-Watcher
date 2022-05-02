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
    
    private let imageView = UIImageView(image: UIImage(named: "tray.2.fill"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
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

//MARK: Setting right button in navigation controller
extension LiveNewsController {
    private struct Const {
        /// Image height/width for Large NavBar state
        static let ImageSizeForLargeState: CGFloat = 40
        /// Margin from right anchor of safe area to right anchor of Image
        static let ImageRightMargin: CGFloat = 16
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Large NavBar state
        static let ImageBottomMarginForLargeState: CGFloat = 12
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Small NavBar state
        static let ImageBottomMarginForSmallState: CGFloat = 6
        /// Image height/width for Small NavBar state
        static let ImageSizeForSmallState: CGFloat = 32
        /// Height of NavBar for Small state. Usually it's just 44
        static let NavBarHeightSmallState: CGFloat = 44
        /// Height of NavBar for Large state. Usually it's just 96.5 but if you have a custom font for the title, please make sure to edit this value since it changes the height for Large state of NavBar
        static let NavBarHeightLargeState: CGFloat = 96.5
    }
    
    private func setupUI() {
//        navigationController?.navigationBar.prefersLargeTitles = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(tapGestureRecognizer)
        
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageView)
        imageView.layer.cornerRadius = Const.ImageSizeForLargeState / 2
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -Const.ImageRightMargin),
            imageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageView.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor)
            ])
    }
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
//        let tappedImage = tapGestureRecognizer.view as! UIImageView
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "savednews") as? SavedNewsController
        
        destination!.modalTransitionStyle = .coverVertical//.crossDissolve
        destination!.modalPresentationStyle = .fullScreen
        self.present(destination!, animated: true, completion: nil)
    }
}


// MARK: - Table Delegate
extension LiveNewsController: UITableViewDelegate, UITableViewDataSource, SFSafariViewControllerDelegate {
    
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
                
        if let url = URL(string: urlString) {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            vc.delegate = self
            present(vc, animated: true)
        }
        //        UIApplication.shared.open(url)
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        dismiss(animated: true)
    }
}



