//
//  TickerNewsController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/5/21.
//

import UIKit

struct TickerNews {
    let headline: String
    let author: String
    let pubDate: String
    let linkHeadline: String
}

class TickerNewsController: UIViewController {

    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    var ticker = "AAPL"
    var tickerNews: [TickerNews] = []
    let saveHeadlines = SaveHeadlines()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tickerLabel.text = ticker
        
        loadTickerNews()
        
        
    }
    
    
    func loadTickerNews() {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "yahoo-finance15.p.rapidapi.com"
        ]

        let urlString = "https://yahoo-finance15.p.rapidapi.com/api/yahoo/ne/news/\(ticker)"
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                //print(error)
            } else {
                let httpResponse = response as? HTTPURLResponse
                //print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                //print (json)
                
                let news = json!["item"] as! [Any]
                
                for (index, new) in news.enumerated() {
                
                    if index == 10 {
                        break
                    }
                    
                    let foundNew = new as? [String: Any]
                    let title = foundNew!["title"] as! String
                    let date = foundNew!["pubDate"] as! String
                    let link = foundNew!["link"] as! String
                    
                    
                    let tickerNew = TickerNews.init(headline: title, author: "", pubDate: date, linkHeadline: link)
                    
                    print (tickerNew)
                    self.tickerNews.append(tickerNew)
                }

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })

        dataTask.resume()
    }


}


extension TickerNewsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickerNews.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TickerNewsCell", for: indexPath) as! TickerNewsViewCell
        
        tickerLabel.text = ticker
        
        cell.headlineLabel.text = tickerNews[indexPath.row].headline
        cell.dateLabel.text = tickerNews[indexPath.row].pubDate
       
        cell.linkButton.titleLabel?.text = tickerNews[indexPath.row].linkHeadline
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
        let title = self.tickerNews[index].headline
        let link = tickerNews[index].linkHeadline
        let dateOfNew = tickerNews[index].pubDate

        print ("SAVED NEW")
        let boldConfig = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
        let boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: boldConfig)

        sender.setImage(boldSearch, for: .normal)
        sender.tintColor = .red
        
        if saveHeadlines.saveHeadlines(headline: title, date: dateOfNew, link: link) {
            let boldConfig = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
            let boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: boldConfig)

            sender.setImage(boldSearch, for: .normal)
            sender.tintColor = .red
            print ("\(title) saved article")
        }
    }

    @objc func shareTitle(sender: UIButton){
        sender.animateButton(sender: sender, duration: 0.1)
        let index = sender.tag
        let headline = self.tickerNews[index].headline
        let link = self.tickerNews[index].linkHeadline

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
