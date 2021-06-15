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


    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        //newsItems = savedNews.loadNews()
    }
    
    @objc func refresh(_ sender: AnyObject) {
        newsItems = savedNews.loadNews()
        if !newsItems.isEmpty {
            refreshControl.endRefreshing()
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        newsItems = savedNews.loadNews()
        if !newsItems.isEmpty {
            tableView.reloadData()
        }
    }
    
    
    
    @IBAction func deleteAllButton(_ sender: UIButton) {
        savedNews.deleteNews(headline: "", date: "", deleteAll: true)
        newsItems.removeAll()
        tableView.reloadData()
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
            savedNews.deleteNews(headline: headline, date: date, deleteAll: false)
            newsItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
        }
    }
}

