//
//  SavedHeadlinesController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/24/21.
//


import UIKit
import AMPopTip


class SavedNewsController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    let savedNews = UserSaveNews()
    var newsItems: [UserSavedNewsItem] = []
    var alreadyLaunched = false
    let refreshControl = UIRefreshControl()
    private let imageView = UIImageView(image: UIImage(systemName: "trash.circle.fill"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingSavedNews")
        UserDefaults.standard.set(true, forKey: "firstLaunchingSavedNews")
        UserDefaults.standard.synchronize()
        
        //change to true for testing
        if !isFirstLaunch {
            alreadyLaunched = false
        } else {
            alreadyLaunched = true
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)        
    }
    
    @objc func refresh(_ sender: AnyObject) {
        newsItems = savedNews.loadNews()
        if !newsItems.isEmpty {
            refreshControl.endRefreshing()
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showImage(true)
        
        newsItems = savedNews.loadNews()
        if !newsItems.isEmpty {
            tableView.reloadData()
        }
    }
    
    @IBAction func shareHeadline(_ sender: UIButton) {
        
        sender.animateButton(sender: sender, duration: 0.1)
        let index = sender.tag
        let headline = newsItems[index].headline
        let date = newsItems[index].pubDate
        
        let objectToShare = [headline, " | ", date] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectToShare, applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func linkButton(_ sender: UIButton) {
        //guard let urlString = sender.titleLabel?.text else { return }
        let index = sender.tag
        let urlString = newsItems[index].link
        
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
}


extension SavedNewsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "headlineCell", for: indexPath) as! SavedNewsViewCell
        
        cell.headlineLabel.text = newsItems[indexPath.row].headline
        cell.dateLabel.text = newsItems[indexPath.row].pubDate
        
        if !alreadyLaunched {
            if indexPath.row == 0  {
                cell.showFirstTimeNotification(whereView: cell.headlineLabel)
            }
            if indexPath.row == 2 {
                cell.showSecondTimeNotification(whereView: cell.headlineLabel)
            }
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let headline = newsItems[indexPath.row].headline
            let date = newsItems[indexPath.row].pubDate
            _ = savedNews.deleteNews(headline: headline, date: date, deleteAll: false)
            newsItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
        }
    }
}

//MARK: Right top button in navigation controller
extension SavedNewsController {
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
        static let ImageSizeForSmallState: CGFloat = 28
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
        _ = savedNews.deleteNews(headline: "", date: "", deleteAll: true)
        newsItems.removeAll()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
    }
    
    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageView.alpha = show ? 1.0 : 0.0
        }
    }
}
