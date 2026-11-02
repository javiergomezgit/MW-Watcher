//
//  NewsCallAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/3/25.
//

import FirebaseAuth
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
    
    ///The Bullish Square server's /v1/market-brief answer.
    private struct MarketBriefResponse: Decodable {
        let generatedAt: String
        let bullets: [Bullet]
        let stories: [MarketNewsResponse.Article]

        struct Bullet: Decodable {
            let text: String
            let sources: [Int]
        }
    }

    //MARK: API call for the market brief
    ///"Why markets moved", or nil when there is none to show: no key on the server, no stories
    ///yet, or no connection. The card is decoration, so nil just means no card. Completes
    ///exactly once. (BS-242)
    ///
    ///The server writes it with Claude at most hourly and shares it between every user.
    func loadMarketBrief(completion: @escaping(MarketBrief?) -> Void) {
        MarketDataServer.authorizedRequest(path: "/v1/market-brief") { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                print("Market brief could not reach the server: \(error)")
                completion(nil)
                return
            case .success(let authorized):
                request = authorized
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let data = data,
                      let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    //503 is "no brief yet", expected until the server has a key and stories.
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("Market brief server answered \(httpResponse.statusCode)")
                    }
                    completion(nil)
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(MarketBriefResponse.self, from: data)
                    completion(Self.marketBrief(from: decoded))
                } catch let error as NSError {
                    print("Market brief could not be read: \(error.localizedDescription)")
                    completion(nil)
                }
            }.resume()
        }
    }

    ///Checks the answer again rather than trusting it: a line citing a story that is not there
    ///is dropped, and a brief with no line left, or an unreadable date, is no brief.
    private static func marketBrief(from response: MarketBriefResponse) -> MarketBrief? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let generatedAt = formatter.date(from: response.generatedAt) else {
            print("Market brief has an unreadable date: \(response.generatedAt)")
            return nil
        }
        let stories = response.stories.map {
            MarketBrief.Story(headline: $0.headline, link: $0.url, source: $0.source)
        }
        let lines = citedLines(response.bullets, storyCount: stories.count, uncitedAllowed: false)
        return lines.isEmpty ? nil : MarketBrief(generatedAt: generatedAt, lines: lines, stories: stories)
    }

    ///The Bullish Square server's /v1/news/ask answer: the brief's shape plus whether it answered.
    private struct NewsAnswerResponse: Decodable {
        let answered: Bool
        let bullets: [MarketBriefResponse.Bullet]
        let stories: [MarketNewsResponse.Article]
    }

    ///Why Ask AI gave no answer, worded for the reader.
    enum AskError: Error {
        ///The plan's questions for today are used up; the number when the server said it.
        case dailyLimit(Int?)
        case busy
        case unavailable

        var message: String {
            switch self {
            case .dailyLimit(let limit?):
                return "You've used your \(limit) questions for today. Try again tomorrow."
            case .dailyLimit(nil):
                return "You've asked the most questions for today. Try again tomorrow."
            case .busy:
                return "Ask AI is busy right now. Try again later."
            case .unavailable:
                return "Ask AI isn't available right now."
            }
        }
    }

    private static let installIDKey = "newsAskInstallID"

    ///A random ID for this install, kept in UserDefaults, that carries the server's daily
    ///question limit while signed out. Not tied to the person or the device.
    private static var installID: String {
        if let stored = UserDefaults.standard.string(forKey: installIDKey) {
            return stored
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: installIDKey)
        return created
    }

    //MARK: API call for Ask AI
    ///A reader's question answered from the last 20 days of Markets and Economy stories.
    ///Completes exactly once. (BS-243)
    ///
    ///A POST to the Bullish Square server's /v1/news/ask, so the question stays out of the URL
    ///and the server's request log. The server shares an answer for an hour and limits new
    ///questions a day by plan: by account when signed in, so the limit follows the user to a new
    ///phone, by install when not. (BS-246)
    func askNews(question: String, completion: @escaping(Result<NewsAnswer, AskError>) -> Void) {
        //The server refuses characters questions do not use; they become spaces here.
        var askable = CharacterSet.alphanumerics
        askable.insert(charactersIn: " .,&'$%?!:;()/-")
        let cleaned = String(String.UnicodeScalarView(question.unicodeScalars.map { askable.contains($0) ? $0 : " " }))
            .split(separator: " ")
            .joined(separator: " ")
        guard cleaned.count >= 3, let body = try? JSONEncoder().encode(["question": String(cleaned.prefix(200))]) else {
            completion(.failure(.unavailable))
            return
        }

        MarketDataServer.authorizedRequest(path: "/v1/news/ask") { result in
            var request: URLRequest
            switch result {
            case .failure(let error):
                print("Ask AI could not reach the server: \(error)")
                completion(.failure(.unavailable))
                return
            case .success(let authorized):
                request = authorized
            }
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Self.installID, forHTTPHeaderField: "X-Install-ID")
            //Haiku takes a few seconds; the 10-second default is too tight.
            request.timeoutInterval = 30

            Self.signInToken { idToken in
                var signed = request
                if let idToken {
                    signed.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                }
                Self.sendQuestion(signed, completion: completion)
            }
        }
    }

    ///The server's 429 answer: which limit, and the plan's allowance when it is the asker's.
    private struct AskRefusal: Decodable {
        let error: String
        let limit: Int?
    }

    ///The signed-in user's Firebase ID token, so the server counts Ask AI by account; nil when
    ///signed out or when no token can be had, and the question then counts by install.
    private static func signInToken(completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        user.getIDToken { token, error in
            if let error {
                print("Sign-in token unavailable, asking by install: \(error.localizedDescription)")
            }
            completion(token)
        }
    }

    private static func sendQuestion(_ request: URLRequest, completion: @escaping(Result<NewsAnswer, AskError>) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, let httpResponse = response as? HTTPURLResponse else {
                print("Ask AI request failed: \(String(describing: error))")
                completion(.failure(.unavailable))
                return
            }
            switch httpResponse.statusCode {
            case 200:
                break
            case 429:
                let refusal = try? JSONDecoder().decode(AskRefusal.self, from: data)
                completion(.failure(refusal?.error == "daily_limit" ? .dailyLimit(refusal?.limit) : .busy))
                return
            default:
                print("Ask AI server answered \(httpResponse.statusCode)")
                completion(.failure(.unavailable))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(NewsAnswerResponse.self, from: data)
                let stories = decoded.stories.map {
                    MarketBrief.Story(headline: $0.headline, link: $0.url, source: $0.source)
                }
                let lines = Self.citedLines(decoded.bullets, storyCount: stories.count, uncitedAllowed: !decoded.answered)
                guard !lines.isEmpty else {
                    completion(.failure(.unavailable))
                    return
                }
                completion(.success(NewsAnswer(answered: decoded.answered, lines: lines, stories: stories)))
            } catch let error as NSError {
                print("Ask AI answer could not be read: \(error.localizedDescription)")
                completion(.failure(.unavailable))
            }
        }.resume()
    }

    ///The lines whose citations all point at stories that were sent. A line citing nothing is
    ///kept only when allowed: an answer saying the stories do not cover the question.
    private static func citedLines(_ bullets: [MarketBriefResponse.Bullet], storyCount: Int, uncitedAllowed: Bool) -> [MarketBrief.Line] {
        bullets.compactMap { bullet in
            let text = bullet.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let citesOnlyWhatWasSent = bullet.sources.allSatisfy { $0 >= 1 && $0 <= storyCount }
            guard !text.isEmpty, citesOnlyWhatWasSent, !bullet.sources.isEmpty || uncitedAllowed else {
                print("Answer line dropped, it cites stories that are not there: \(bullet.sources)")
                return nil
            }
            return MarketBrief.Line(text: text, sources: bullet.sources)
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
