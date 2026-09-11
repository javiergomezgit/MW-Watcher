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
           
            if let error = error {
                print(error)
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            //A non-dictionary body, an error payload, or a missing articles array all used to
            //hit a bare return that abandoned the completion handler. SceneDelegate chains the
            //three category fetches off this callback, so one bad body stopped the remaining
            //categories from ever being requested, and Live News sat on its spinner for the
            //full 20-second cache poll before giving up.
            let decoded = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let json = decoded, let jsonNews = json["articles"] as? [Any] else {
                completion(nil)
                return
            }
            
            let placeholder = UIImage(named: "mw-logo") ?? UIImage()
            var newsItems = [NewsItem]()
            var imageURLs = [Int: String]()
            
            for jsonNew in jsonNews {
                
                let dictionaryNew = jsonNew as! [String: Any]
                
                let authorDictionary = dictionaryNew["source"] as! [String: Any]
                let authorName = authorDictionary["name"] as! String
                
                let headline = dictionaryNew["title"] as! String
                let link = dictionaryNew["url"] as! String
                
                let notFormatedDate = dictionaryNew["publishedAt"] as! String
                let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                
                if let imageURL = dictionaryNew["image"] as? String, imageURL.isValidURL {
                    imageURLs[newsItems.count] = imageURL
                }
                
                let newsItem = NewsItem.init(headline: headline, link: link, pubDate: pubDate, ticker: "", author: authorName, image: placeholder)
                newsItems.append(newsItem)
            }
            
            //Images are fetched concurrently rather than one blocking download at a time
            //on this completion handler, which stalled the whole feed.
            Support.sharedSupport.fillImages(into: newsItems, urls: imageURLs, imagePath: \NewsItem.image) { itemsWithImages in
                print("✅ Cached: \(keySource) — \(itemsWithImages.count) articles from News CallAPI")
                completion(itemsWithImages)
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
                
                let placeholder = UIImage(named: "mw-logo") ?? UIImage()
                var newsItems = [TickerNews]()
                var imageURLs = [Int: String]()
                
                for jsonNew in entries {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let headline = dictionaryNew["description"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    //Was force cast, which trapped whenever promoImage carried no url
                    if let imageDictionary = dictionaryNew["promoImage"] as? [String: Any],
                       let imageLink = imageDictionary["url"] as? String, imageLink.isValidURL {
                        imageURLs[newsItems.count] = imageLink
                    }

                    let author = dictionaryNew["type"] as! String
                    
                    let notFormatedDate = dictionaryNew["dateFirstPublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTime(timeString: notFormatedDate)
                    
                    let newsItem = TickerNews.init(headline: headline, pubDate: pubDate, linkHeadline: link, author: author, image: placeholder)
                    newsItems.append(newsItem)
                }
                
                Support.sharedSupport.fillImages(into: newsItems, urls: imageURLs, imagePath: \TickerNews.image) { itemsWithImages in
                    completion(itemsWithImages)
                }
            }
        })
        dataTask.resume()
    }
}
