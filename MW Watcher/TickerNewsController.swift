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
}

class TickerNewsController: UIViewController {

    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    
    var ticker = "AAPL"
    var tickerNewsArray: [TickerNews] = []
    let saveHeadlines = UserSaveNews()

    
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
                self.showAlert(title: "Error", message: "Connection Error", titleButton: "Ok")
            } else {
                //let httpResponse = response as? HTTPURLResponse
                //print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                //print (json)
                
                let news = json!["item"] as! [Any]
                
                for (index, new) in news.enumerated() {
                
                    if index == 10 {
                        break
                    }
                    
                    let foundNew = new as? [String: Any]
                    let headline = foundNew!["title"] as! String
                    let date = self.newLocalTime(timeString: foundNew!["pubDate"] as! String)
                    let link = foundNew!["link"] as! String
                    
                    let tickerNews = TickerNews.init(headline: headline, pubDate: date, linkHeadline: link)
                    
                    print (tickerNews)
                    self.tickerNewsArray.append(tickerNews)
                }

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })

        dataTask.resume()
    }
    
    func newLocalTime(timeString: String) -> String {
        print (timeString)
        //Get date and format
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")
        
        //Convert format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current

        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        let newLocalTime = dateFormatter.string(from: dateObj!)

        return newLocalTime
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

        print ("SAVED NEW")
        let boldConfig = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
        let boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: boldConfig)

        sender.setImage(boldSearch, for: .normal)
        sender.tintColor = .red
        
        if saveHeadlines.saveNews(headline: headline, date: dateOfNew, link: link) {
            let boldConfig = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .bold)
            let boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: boldConfig)

            sender.setImage(boldSearch, for: .normal)
            sender.tintColor = .red
            print ("\(headline) saved article")
        }
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
