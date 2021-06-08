//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SafariServices

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

    override func viewDidLoad() {
        super.viewDidLoad()

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
    

    
    func loadNews(){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url: NSURL(string: "https://bing-news-search1.p.rapidapi.com/news?safeSearch=Off&category=Business")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error)
            } else {
                let httpResponse = response as? HTTPURLResponse
                //print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                print (json!)
                
                let jsonNews = json!["value"] as! [Any]
                
                self.newsItems.removeAll()
                
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let notFormatedDate = dictionaryNew["datePublished"] as! String
                    let pubDate = self.newLocalTime(timeString: notFormatedDate)
                    
                    let headline = dictionaryNew["name"] as! String
                    
                    let link = dictionaryNew["url"] as! String
                    
                    print (dictionaryNew)
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]
                    print (imageDictionary)
                    
                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        //print (imageJSON)
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = self.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let newsItem = NewsItem.init(headline: headline, link: link, pubDate: pubDate, ticker: "", author: author, image: downloadedImage)
                    self.newsItems.append(newsItem)
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                }
                
            }
        })
        dataTask.resume()
    }
    
    func newLocalTime(timeString: String) -> String {

        let date = timeString.components(separatedBy: ".")

        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatterGet.timeZone = TimeZone(identifier: "CDT")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone(identifier: "PDT")//NSTimeZone(name: "America/Los_Angeles") as TimeZone?
       
        let dateObj: Date? = dateFormatterGet.date(from: date[0] + "Z")
        return dateFormatter.string(from: dateObj!)
    }
   
    
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage()
        let url = URL(string: URLImage)
        do {
            let data = try Data(contentsOf: url!)
            let imageToCache = UIImage(data: data)!
            imageCache.setObject(imageToCache, forKey: URLImage as NSString)
            image = imageToCache
        } catch {
            image = UIImage(named: "mw-logo")!
        }
        return image
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
        
        print (sender.tag)
        print (headline)

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

//        let vc = SFSafariViewController(url: url)
//        present(vc, animated: true)
    }
}


//MARK: - Button delegate
extension UIButton {
    func animateButton(sender: UIButton, duration: Double) {
        UIButton.animate(withDuration: duration,
                         animations: {
                            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                            },
                         completion: { finish in
                            UIButton.animate(withDuration: duration, animations: {
                                sender.transform = CGAffineTransform.identity
                            })
                         }
        )
   }
}
