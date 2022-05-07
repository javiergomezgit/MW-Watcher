//
//  NewsAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/6/22.
//

import Foundation
//import SwiftyJSON
import UIKit

final class NewsAPI {
    static let shared = NewsAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
    }
    
    //MARK: API call for live news
    func loadAllNews(completion: @escaping([NewsItem]?) -> Void){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url:
                                            NSURL(string: "https://bing-news-search1.p.rapidapi.com/news?safeSearch=Off&category=Business")! as URL,
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
                let jsonNews = json!["value"] as! [Any]
                     
                var newsItems = [NewsItem]()
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let notFormatedDate = dictionaryNew["datePublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                    let headline = dictionaryNew["name"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]

                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let newsItem = NewsItem.init(headline: headline, link: link, pubDate: pubDate, ticker: "", author: author, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
    
    
    //MARK: API call for news on specific stock
    func loadStockNews(ticker: String, completion: @escaping([TickerNews]?) -> Void){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        //let request = NSMutableURLRequest(url: NSURL(string: "https://bing-news-search1.p.rapidapi.com/news/search?q=AAPL&freshness=Day&textFormat=Raw&safeSearch=Off")! as URL,

        let urlString = "https://bing-news-search1.p.rapidapi.com/news/search?q=\(ticker)&freshness=Day&textFormat=Raw&safeSearch=Off"
        
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
                let jsonNews = json!["value"] as! [Any]
                     
                var newsItems = [TickerNews]()
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let notFormatedDate = dictionaryNew["datePublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                    let headline = dictionaryNew["name"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]

                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String

                    let newsItem = TickerNews.init(headline: headline, pubDate: pubDate, linkHeadline: link, author: author, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
}
