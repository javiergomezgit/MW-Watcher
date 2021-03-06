//
//  TickerNewsController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/5/21.
//

import UIKit

struct TickerNews {
    let headline: String
    let pubDate: String
    let linkHeadline: String
    let author: String
    let image: UIImage
}

class TickerNewsController: UIViewController {
    
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    var ticker = ""
    var name = ""
    var tickerNewsArray: [TickerNews] = []
    let saveHeadlines = UserSaveNews()
    var savedRows : [Int: Bool] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tickerLabel.text = ticker
        loadTickerNews()
    }
    
    func loadTickerNews() {
        NewsAPI.shared.loadStockNews(ticker: ticker, name: self.name) { loadedNewsArray in
            if loadedNewsArray != nil {
                self.tickerNewsArray = loadedNewsArray!
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } else {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "OK", over: self)
            }
        }
    }
}


extension TickerNewsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickerNewsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TickerNewsCell", for: indexPath) as! TickerNewsViewCell
        tickerLabel.text = ticker
        
        cell.headlineLabel.text = tickerNewsArray[indexPath.row].headline
        cell.dateLabel.text = tickerNewsArray[indexPath.row].pubDate
        cell.newsImageView.image = tickerNewsArray[indexPath.row].image
        cell.authorLabel.text = tickerNewsArray[indexPath.row].author
        
        cell.linkButton.titleLabel?.text = tickerNewsArray[indexPath.row].linkHeadline
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.addTarget(self, action: #selector(saveHeadline(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func saveHeadline(sender: UIButton) {
        let index = sender.tag
        
        sender.animateButton(sender: sender, duration: 0.1)
        let headline = self.tickerNewsArray[index].headline
        let link = tickerNewsArray[index].linkHeadline
        let dateOfNew = tickerNewsArray[index].pubDate
        
        let configurationButton = sender.currentImage?.configuration
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
        let headline = self.tickerNewsArray[index].headline
        let link = self.tickerNewsArray[index].linkHeadline
        
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
