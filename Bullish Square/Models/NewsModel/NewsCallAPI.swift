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
    
    ///The Bullish Square server's /v1/market-news answer: the /v1/news fields plus who
    ///published each story ("CNBC", or the publication GNews names).
    private struct MarketNewsResponse: Decodable {
        let articles: [Article]
        
        struct Article: Decodable {
            let headline: String
            let url: String
            let published: String
            let source: String
            let imageUrl: String?
        }
    }
    
    //MARK: API call for market news
    ///One News tab topic's stories, newest first, or nil when they could not be loaded.
    ///Completes exactly once.
    ///
    ///Asks the Bullish Square server's /v1/market-news/<topic>, which shares each topic between
    ///every user for an hour: CNBC for Markets and Economy, GNews for World.
    ///The tab used to ask GNews from the phone, with its key built into the app.
    ///(BS-230, BS-231)
    func loadMarketNews(section: String, completion: @escaping([NewsItem]?) -> Void) {
        MarketDataServer.authorizedRequest(path: "/v1/market-news/" + section) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                print("Market news could not reach the server: \(error)")
                completion(nil)
                return
            case .success(let authorized):
                request = authorized
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let data = data,
                      let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let decoded = try? JSONDecoder().decode(MarketNewsResponse.self, from: data) else {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("Market news server answered \(httpResponse.statusCode) for \(section)")
                    }
                    completion(nil)
                    return
                }
                
                //Returned before any picture downloads; the feed loads each one as its row
                //appears. The source is shown on each card.
                let placeholder = UIImage(named: "mw-logo") ?? UIImage()
                let newsItems = decoded.articles.map { article in
                    NewsItem(headline: article.headline,
                             link: article.url,
                             pubDate: Support.sharedSupport.newLocalTimeNews(timeString: article.published),
                             ticker: "",
                             author: article.source,
                             image: placeholder,
                             imageURL: article.imageUrl.flatMap { $0.isValidURL ? $0 : nil })
                }
                completion(newsItems)
            }.resume()
        }
    }
    
    //MARK: API call for news search
    ///Markets and Economy stories from the last 20 days whose headline matches every word,
    ///newest first, or nil when the search could not run. An empty list means nothing matched.
    ///Completes exactly once. (BS-240)
    ///
    ///Asks the Bullish Square server's /v1/news/search, which keeps the archive (BS-239). The
    ///server refuses characters headlines do not use, so "why is Intel down?" loses the "?"
    ///here rather than being refused.
    func searchNews(query: String, completion: @escaping([NewsItem]?) -> Void) {
        var searchable = CharacterSet.alphanumerics
        searchable.insert(charactersIn: " .,&'$%-")
        let cleaned = String(String.UnicodeScalarView(query.unicodeScalars.map { searchable.contains($0) ? $0 : " " }))
            .split(separator: " ")
            .joined(separator: " ")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard !cleaned.isEmpty,
              let encoded = String(cleaned.prefix(60)).addingPercentEncoding(withAllowedCharacters: allowed) else {
            completion([])
            return
        }

        MarketDataServer.authorizedRequest(path: "/v1/news/search?q=" + encoded) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                print("News search could not reach the server: \(error)")
                completion(nil)
                return
            case .success(let authorized):
                request = authorized
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let data = data,
                      let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let decoded = try? JSONDecoder().decode(MarketNewsResponse.self, from: data) else {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("News search server answered \(httpResponse.statusCode) for \(cleaned)")
                    }
                    completion(nil)
                    return
                }

                //The same shape as a topic's stories, so the same cards show them.
                let placeholder = UIImage(named: "mw-logo") ?? UIImage()
                let newsItems = decoded.articles.map { article in
                    NewsItem(headline: article.headline,
                             link: article.url,
                             pubDate: Support.sharedSupport.newLocalTimeNews(timeString: article.published),
                             ticker: "",
                             author: article.source,
                             image: placeholder,
                             imageURL: article.imageUrl.flatMap { $0.isValidURL ? $0 : nil })
                }
                completion(newsItems)
            }.resume()
        }
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
                    //CNBC sends "2026-10-21T13:30:01+0000". This used newLocalTime, which parses
                    //no zone, so every date failed to parse and the label stayed blank. (BS-232)
                    newsItems.append(TickerNews(headline: article.headline,
                                                pubDate: Support.sharedSupport.newLocalTimeNews(timeString: article.published),
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
