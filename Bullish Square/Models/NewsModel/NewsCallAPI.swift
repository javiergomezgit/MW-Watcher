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
    
    //MARK: Decoded response shapes
    ///Every field is optional on purpose. The previous parser force cast each one, so a single
    ///article missing a title, url or timestamp took down the whole feed. Anything essential
    ///that is absent now causes that one article to be skipped.
    private struct AllNewsResponse: Decodable {
        let articles: [Article]?
        
        struct Article: Decodable {
            let title: String?
            let url: String?
            let image: String?
            let publishedAt: String?
            let source: Source?
            
            struct Source: Decodable {
                let name: String?
            }
        }
    }
    
    private struct TickerNewsResponse: Decodable {
        let data: DataBlock?
        
        struct DataBlock: Decodable {
            let symbolEntries: SymbolEntries?
            
            struct SymbolEntries: Decodable {
                let results: [Entry]?
                
                struct Entry: Decodable {
                    let description: String?
                    let url: String?
                    let type: String?
                    let dateFirstPublished: String?
                    let promoImage: PromoImage?
                    
                    struct PromoImage: Decodable {
                        let url: String?
                    }
                }
            }
        }
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
            
            //An error payload or a missing articles array abandons the completion handler if
            //it is not reported. SceneDelegate chains the three category fetches off this
            //callback, so a silent failure stops the remaining categories being requested.
            guard let articles = (try? JSONDecoder().decode(AllNewsResponse.self, from: data))?.articles else {
                completion(nil)
                return
            }
            
            let placeholder = UIImage(named: "mw-logo") ?? UIImage()
            var newsItems = [NewsItem]()
            var imageURLs = [Int: String]()
            
            for article in articles {
                //Skip an article that is missing anything displayed, rather than trapping
                guard let headline = article.title,
                      let link = article.url,
                      let published = article.publishedAt else { continue }
                
                if let imageURL = article.image, imageURL.isValidURL {
                    imageURLs[newsItems.count] = imageURL
                }
                
                //The source name drives the filter chips, so a missing one is grouped rather
                //than dropping an otherwise usable article
                let newsItem = NewsItem(headline: headline,
                                        link: link,
                                        pubDate: Support.sharedSupport.newLocalTimeNews(timeString: published),
                                        ticker: "",
                                        author: article.source?.name ?? "Other",
                                        image: placeholder)
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
            if let error = error {
                print(error)
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            //data, the decoded root, and each of data / symbolEntries / results were force
            //unwrapped or force cast, so any error payload from the provider trapped here.
            guard let entries = (try? JSONDecoder().decode(TickerNewsResponse.self, from: data))?
                .data?.symbolEntries?.results else {
                completion(nil)
                return
            }
            
            let placeholder = UIImage(named: "mw-logo") ?? UIImage()
            var newsItems = [TickerNews]()
            var imageURLs = [Int: String]()
            
            for entry in entries {
                //Skip an entry missing anything displayed, rather than trapping
                guard let headline = entry.description,
                      let link = entry.url,
                      let published = entry.dateFirstPublished else { continue }
                
                if let imageLink = entry.promoImage?.url, imageLink.isValidURL {
                    imageURLs[newsItems.count] = imageLink
                }
                
                let newsItem = TickerNews(headline: headline,
                                          pubDate: Support.sharedSupport.newLocalTime(timeString: published),
                                          linkHeadline: link,
                                          author: entry.type ?? "",
                                          image: placeholder)
                newsItems.append(newsItem)
            }
            
            Support.sharedSupport.fillImages(into: newsItems, urls: imageURLs, imagePath: \TickerNews.image) { itemsWithImages in
                completion(itemsWithImages)
            }
        })
        dataTask.resume()
    }
}
