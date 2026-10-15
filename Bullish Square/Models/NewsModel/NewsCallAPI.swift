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
    
    ///The Bullish Square server's /v1/news answer.
    private struct StockNewsResponse: Decodable {
        let articles: [Article]
        
        struct Article: Decodable {
            let headline: String
            let url: String
            let published: String
            let type: String
            let imageUrl: String?
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

            for article in articles {
                //Skip an article that is missing anything displayed, rather than trapping
                guard let headline = article.title,
                      let link = article.url,
                      let published = article.publishedAt else { continue }

                //The source name drives the filter chips, so a missing one is grouped rather
                //than dropping an otherwise usable article
                let newsItem = NewsItem(headline: headline,
                                        link: link,
                                        pubDate: Support.sharedSupport.newLocalTimeNews(timeString: published),
                                        ticker: "",
                                        author: article.source?.name ?? "Other",
                                        image: placeholder,
                                        imageURL: article.image.flatMap { $0.isValidURL ? $0 : nil })
                newsItems.append(newsItem)
            }

            //Returned before any picture downloads. Waiting for all of them - each with a 15 s
            //timeout - held the whole category back, and was most of the News tab's blank
            //wait. The feed now loads each picture as its row appears.
            completion(newsItems)
        })
        dataTask.resume()
    }
    
    //MARK: API call for news on specific stock
    ///A stock's latest five news items, or nil when they could not be loaded. An empty list
    ///means there is no news for it. Completes exactly once.
    ///
    ///Asks the Bullish Square server's /v1/news, which shares each symbol's news between every
    ///user for 15 minutes. It used to ask CNBC from the phone with the RapidAPI key built into
    ///the app - the last such call. (BS-212)
    func loadStockNews(ticker: String, name: String, completion: @escaping([TickerNews]?) -> Void){
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        guard let symbol = ticker.addingPercentEncoding(withAllowedCharacters: allowed) else {
            completion(nil)
            return
        }
        
        MarketDataServer.authorizedRequest(path: "/v1/news/" + symbol) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                print("News for \(ticker) could not reach the server: \(error)")
                completion(nil)
                return
            case .success(let authorized):
                request = authorized
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let data = data,
                      let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let decoded = try? JSONDecoder().decode(StockNewsResponse.self, from: data) else {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("News server answered \(httpResponse.statusCode) for \(ticker)")
                    }
                    completion(nil)
                    return
                }
                
                let placeholder = UIImage(named: "mw-logo") ?? UIImage()
                var newsItems = [TickerNews]()
                var imageURLs = [Int: String]()
                
                for article in decoded.articles {
                    if let imageLink = article.imageUrl, imageLink.isValidURL {
                        imageURLs[newsItems.count] = imageLink
                    }
                    newsItems.append(TickerNews(headline: article.headline,
                                                pubDate: Support.sharedSupport.newLocalTime(timeString: article.published),
                                                linkHeadline: article.url,
                                                author: article.type,
                                                image: placeholder))
                }
                
                Support.sharedSupport.fillImages(into: newsItems, urls: imageURLs, imagePath: \TickerNews.image) { itemsWithImages in
                    completion(itemsWithImages)
                }
            }.resume()
        }
    }
}
