//
//  NewsCallAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/3/25.
//

import Foundation
import UIKit

final class NewsCallAPI {
    static let shared = NewsCallAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
    }
    
    //MARK: API call for live news
    func loadAllNews(keySource: String, completion: @escaping([NewsItem]?) -> Void){

        let parameters = "category=\(keySource)&lang=en&country=us&max=20"
        let requestURL = "\(KeysNewsCallAPI.loadNewsbaseUrl)\(parameters)&apikey=\(KeysNewsCallAPI.loadNewsKey)"
        
        let request = NSMutableURLRequest(url:
                                            NSURL(string: requestURL)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        
        request.httpMethod = "GET"
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
           
            if (error != nil) {
                completion(nil)
            } else {
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                dump (json!)
                guard let jsonNews = json!["articles"] as? [Any] else {
                    return
                }
                
                var newsItems = [NewsItem]()
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let authorDictionary = dictionaryNew["source"] as! [String: Any]
                    let authorName = authorDictionary["name"] as! String
                    
                    let headline = dictionaryNew["title"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let notFormatedDate = dictionaryNew["publishedAt"] as! String
                    let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                    
                    let imageURL = dictionaryNew["image"] as? String
                    var downloadedImage = UIImage()
                    if imageURL != nil {
                        if imageURL!.isValidURL {
                            downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageURL!)
                        } else {
                            downloadedImage = UIImage(named: "mw-logo")!
                        }
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let newsItem = NewsItem.init(headline: headline, link: link, pubDate: pubDate, ticker: "", author: authorName, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
    
    //MARK: API call for news on specific stock
    func loadStockNews(ticker: String, name: String, completion: @escaping([TickerNews]?) -> Void){
        
        let headers = [
            "x-rapidapi-key": KeysNewsCallAPI.loadStockNewsKey,
            "x-rapidapi-host": KeysNewsCallAPI.loadStockNewsHost
        ]
        let urlStringSpaces = "\(KeysNewsCallAPI.loadStockNewsbaseUrl)\(ticker)"
        
        var urlString = urlStringSpaces.replacingOccurrences(of: " ", with: "%20")
        urlString = urlString.replacingOccurrences(of: "^", with: "%5E")
        
        let request = NSMutableURLRequest(url:
                                            NSURL(string: urlString)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                completion(nil)
            } else {
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                dump (json!)
                let jsonNews = json!["data"] as! [String: Any]
                let newsEntries = jsonNews["symbolEntries"] as! [String: Any]
                let entries = newsEntries["results"] as! [Any]
                
                var newsItems = [TickerNews]()
                for jsonNew in entries {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let headline = dictionaryNew["description"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let imageDictionary = dictionaryNew["promoImage"] as? [String : Any]
                    
                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageLink = imageDictionary?["url"] as! String // as? [String: Any]
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }

                    let author = dictionaryNew["type"] as! String
                    
                    let notFormatedDate = dictionaryNew["dateFirstPublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTime(timeString: notFormatedDate)
                    
                    let newsItem = TickerNews.init(headline: headline, pubDate: pubDate, linkHeadline: link, author: author, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
}
