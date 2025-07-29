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
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    
    var newsItems: [NewsItem] = []
    var backupNewsItems: [NewsItem] = []
    let saveHeadlines = UserSaveNews()
    var refreshControl = UIRefreshControl()
    var overlay : UIView!
    var alert : UIAlertController!
//    var activityIndicator : UIActivityIndicatorView!
    let child = Spinner()

    var loadedTimes = 0
    var alreadyLaunched = false
    var savedRows : [Int: Bool] = [:]
    
    private let imageViewSavedNews = UIImageView(image: UIImage(named: "tray.2.fill"))
    private let imageViewSearchNews = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    
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
        collectionView.delegate = self
        collectionView.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        loadNews()
    }
    
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout! {
        didSet {
            collectionLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }
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

    var sources = ["ALL"]
    func loadNews(){
        refreshControl.beginRefreshing()
        startStopSpinner(start: true)
        
        let selectedSources = ["business", "world", "general"]
        var error = false
        var tempSources : Set<String> = []

        var count = 0
        for source in selectedSources {
            NewsCallAPI.shared.loadAllNews(keySource: source) { allNews in
                if allNews == nil {
                    print ("error getting from one of the sources")
                    error = true
                } else {
                    if count == 0 {
                        self.sources.removeAll()
                        self.newsItems.removeAll()
                        self.backupNewsItems.removeAll()
                        self.sources.append("ALL")
                    }
                    for news in allNews! {
                        let inserted = tempSources.insert(news.author)
                        if inserted.inserted {
                            self.sources.append(news.author)
                        }
                        self.newsItems.append(news)
                        self.backupNewsItems.append(news)
                    }
                    
                    if selectedSources.count-1 == count {
                        DispatchQueue.main.async {
                            self.sources.sort()
                            self.tableView.reloadData()
                            self.collectionView.reloadData()
                            self.refreshControl.endRefreshing()
                            self.startStopSpinner(start: false)
                        }
                    }
                }
                count += 1
            }
        }
        
        if error {
            DispatchQueue.main.async {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error, try later!", titleButton: "OK", over: self)
            }
        }
        if !self.alreadyLaunched {
            self.showFirstTimeNotification(whereView: self.tableView)
        }
        print (self.newsItems.count)
    }
}

//MARK: Right top button in navigation controller
extension LiveNewsController {
    private struct Const {
        /// Image height/width for Large NavBar state
        static let ImageSizeForLargeState: CGFloat = 36
        /// Margin from right anchor of safe area to right anchor of Image
        static let ImageRightMargin: CGFloat = 18
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Large NavBar state
        static let ImageBottomMarginForLargeState: CGFloat = 14
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Small NavBar state
        static let ImageBottomMarginForSmallState: CGFloat = 5
        /// Image height/width for Small NavBar state
        static let ImageSizeForSmallState: CGFloat = 20
        /// Height of NavBar for Small state. Usually it's just 44
        static let NavBarHeightSmallState: CGFloat = 44
        /// Height of NavBar for Large state. Usually it's just 96.5 but if you have a custom font for the title, please make sure to edit this value since it changes the height for Large state of NavBar
        static let NavBarHeightLargeState: CGFloat = 96.5
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
    
    private func setupUI() {
        //navigationController?.navigationBar.prefersLargeTitles = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageSavedNewsTapped(tapGestureRecognizer:)))
        imageViewSavedNews.isUserInteractionEnabled = true
        imageViewSavedNews.tintColor = .label
        imageViewSavedNews.addGestureRecognizer(tapGestureRecognizer)
        
        let tapGestureRecognizerSearch = UITapGestureRecognizer(target: self, action: #selector(imageSearchNewsTapped(tapGestureRecognizer:)))
        imageViewSearchNews.isUserInteractionEnabled = true
        imageViewSearchNews.tintColor = .label
        imageViewSearchNews.addGestureRecognizer(tapGestureRecognizerSearch)
        
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewSavedNews)
        navigationBar.addSubview(imageViewSearchNews)
        //        imageView.layer.cornerRadius = Const.ImageSizeForLargeState / 2
        //        imageView.clipsToBounds = true
        imageViewSavedNews.translatesAutoresizingMaskIntoConstraints = false
        imageViewSearchNews.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageViewSavedNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -Const.ImageRightMargin),
            imageViewSavedNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSavedNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSavedNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor),
            imageViewSearchNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(imageViewSavedNews.frame.width*2.5)),
            imageViewSearchNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSearchNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSearchNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor)
        ])
    }
    
    @objc func imageSavedNewsTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "savednews") as? SavedNewsController
        
        destination!.modalTransitionStyle = .coverVertical//.crossDissolve
        destination!.modalPresentationStyle = .fullScreen
        self.show(destination!, sender: self)
    }
    
    @objc func imageSearchNewsTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let vc = SearchNewsController()
        vc.completion = { [weak self] tickerTyped in
            let ticker = tickerTyped.first?.key
            dump (ticker)
            //self.startStopSpinner(start: true)
            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
                let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController
                destination!.ticker = ticker!
                destination!.modalTransitionStyle = .crossDissolve
                self?.present(destination!, animated: true) {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Didn't find any related news", titleButton: "OK", over: self!)
                }
            }
            
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
    }
    
    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageViewSavedNews.alpha = show ? 1.0 : 0.0
            self.imageViewSearchNews.alpha = show ? 1.0 : 0.0
        }
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
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.addTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender: )), for: .touchUpInside)
        
        return cell
    }
    
    @objc func shareTitle(sender: UIButton) {
       sender.animateButton(sender: sender, duration: 0.1)
        
       let newsItem = self.newsItems[sender.tag]
       let headline = newsItem.headline
       let date = newsItem.pubDate
       let author = newsItem.author
       let link = newsItem.link
       let image = newsItem.image
        
       let formattedText = """
        
        📰 \(headline)
            
        📅 \(date)
        👤 Source: \(author)
            
        🔗 Read more: \(link)
        
        Shared via Market Watch Social 📱
        """
        
        // Create activity items array with both text and image
        var activityItems: [Any] = [formattedText]
        
        // Add image if it's not a placeholder or empty image
        if image.size.width > 1 && image.size.height > 1 {
                activityItems.append(image)
        }
        
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        present(activityVC, animated: true)
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
       // dismiss(animated: true)
    }
}


// MARK: - Collection View Delegate
extension LiveNewsController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sources.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionCell", for: indexPath) as! LiveNewsCollectionViewCell
        
        let text = sources[indexPath.row]
        cell.setValues(source: text)//.uppercased())
        
        cell.maxWidth = collectionView.bounds.width //- 16
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let selectedSource = sources[indexPath.row]
        
        if selectedSource == "ALL" {
            newsItems = backupNewsItems
        } else {
            var tempNew: [NewsItem] = []
            for newsItem in backupNewsItems {
                if newsItem.author == selectedSource {
                    tempNew.append(newsItem)
                }
            }
            newsItems = tempNew
        }
        tableView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 25, height: 35)
    }
    
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 15.0
    }

    func collectionView(_ collectionView: UICollectionView, layout
        collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
    
}

