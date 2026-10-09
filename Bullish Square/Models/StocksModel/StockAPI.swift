//
//  StockAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/2/25.
//

import Foundation
import SwiftyJSON
import UIKit

final class StockAPI {
    static let shared = StockAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
        case freeVersion
        case noData
        case logoUnavailable    //the provider has no logo for this symbol; permanent
        case logoDownloadFailed //transport or decode failure; worth retrying
    }
    
    //MARK: Decoded response shapes
    ///Every field is optional. The previous parser force cast each one, so a single index
    ///missing a short name or reporting a null price crashed the launch prefetch.
    private struct GeneralMarketsResponse: Decodable {
        let quoteResponse: QuoteResponse?
        
        struct QuoteResponse: Decodable {
            let result: [Quote]?
            
            struct Quote: Decodable {
                let symbol: String?
                let shortName: String?
                let regularMarketPrice: Double?
                let regularMarketChangePercent: Double?
                let regularMarketTime: Int?
            }
        }
    }
    
    //MARK: API call for search/add of single stock
    func getFeaturesTicker(tickerSingle: String, completion: @escaping (Result<TickersFeatures, Error>) -> Void) {
        let headers = [
            "x-rapidapi-key": KeysStocksAPI.apiKeyStockSearchAdd,
            "x-rapidapi-host": KeysStocksAPI.apiHost
        ]
        
        let urlString = KeysStocksAPI.baseUrlStockSearchAdd + tickerSingle
        var json: [String: Any]? = [:]
        
        //if it's not a valid url, exit the completion with error
        if !urlString.isValidURL {
            completion(.failure(APIError.invalidTicker))
            return
        }
        
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error!)
                completion(.failure(error!))
            } else {
                json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                if json == nil  {
                    completion(.failure(APIError.invalidJSON))
                }
                
                if let tickerFound = json!["quoteResponse"] {
                    guard let tickerDictionary = tickerFound as? [String: Any] else {
                        completion(.failure(APIError.invalidJSON))
                        return
                    }
                    
                    if tickerDictionary["error"] == nil {
                        completion(.failure(APIError.invalidJSON))
                    } else {
                        let resultArray = tickerDictionary["result"] as? [Any]
                        if let tickerValue = resultArray?.first as? [String: Any] {
                            let nameCompany = tickerValue["longName"] as? String
                            if nameCompany == nil {
                                completion(.failure(APIError.freeVersion))
                                return
                            }
                            
                            self.getLogoStock(ticker: tickerSingle) { result in
                                switch result {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success(let imageCompany):
                                    let tickerFeatures = TickersFeatures(ticker: tickerSingle, nameTicker: nameCompany!, imageTicker: imageCompany, imageTickerName: tickerSingle)
                                    completion(.success(tickerFeatures))
                                }
                            }
                        } else {
                            completion(.failure(APIError.invalidJSON))
                        }
                    }
                } else {
                    print (APIError.tickerNotFound)
                    completion(.failure(APIError.invalidURL))
                }
            }
        })
        dataTask.resume()
    }
    
    //MARK: API Call for getting logo for specific stock
    func getLogoStock(ticker: String, completion: @escaping(Result<UIImage, Error>) -> Void) {
        let headers = [
            "X-RapidAPI-Host": KeysStocksAPI.apiKeyLogoStockHost,
            "X-RapidAPI-Key": KeysStocksAPI.apiKeyLogoStock
        ]
        
        let urlString = "\(KeysStocksAPI.apiLogoBaseURL)\(ticker)"
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
        dump (request.url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            //Throttling and server faults have to stay retryable, so they are separated out
            //before the body is inspected. A body with no url is otherwise indistinguishable
            //from a symbol that genuinely has no logo.
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                completion(.failure(APIError.logoDownloadFailed))
                return
            }
            
            do {
                let json = try JSON(data: data)
                
                if let logoURL = json["url"].string, !logoURL.isEmpty {
                    //Downloaded asynchronously. This used to be a blocking call made from
                    //inside this completion handler, so adding several tickers at once starved
                    //the session's queue and some logos silently became the placeholder.
                    Support.sharedSupport.downloadImage(from: logoURL) { image in
                        guard let image = image else {
                            completion(.failure(APIError.logoDownloadFailed))
                            return
                        }
                        completion(.success(image))
                    }
                    return
                }
                
                //No usable url. Two shapes mean the logo permanently does not exist:
                //  {"meta":{"symbol":"AAPD"},"url":""}          symbol recognised, no logo
                //  {"code":404,"status":"error", ...}           symbol not recognised
                //ETFs commonly return the first, with HTTP 200 and an empty url. Treating that
                //as transient made the app re-request it on every appearance, forever.
                //Anything else, such as a rate-limit body carrying neither meta nor a 404, is
                //genuinely transient and worth retrying.
                let recognisedSymbol = json["meta"]["symbol"].string != nil
                let explicitlyNotFound = json["status"].string == "error" && json["code"].int == 404
                
                if recognisedSymbol || explicitlyNotFound {
                    completion(.failure(APIError.logoUnavailable))
                } else {
                    completion(.failure(APIError.logoDownloadFailed))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    //MARK: API call for a single stock returning current price
    ///One stock's price, through the Bullish Square server like the watchlist's.
    ///
    ///This called RapidAPI from the phone with the key built into the app, one request per
    ///chart opened from search. It now asks the server's /v1/spark for the one symbol, shared
    ///through its cache, and reuses the watchlist's parsing - which also drops a last bar
    ///with no trade. The old parse read that bar raw and showed a price of $0.0. (BS-212)
    func getPriceSingleTicker(ticker: String, timeRange: String, completion: @escaping (Result<TickersCurrentValues, Error>) -> Void) {
        getPriceMultipleStocks(tickersGroup: ticker, timeRange: timeRange) { result in
            switch result {
            case .success(let values):
                //The server upper-cases symbols, so match without regard to case.
                guard let match = values.first(where: { $0.ticker.caseInsensitiveCompare(ticker) == .orderedSame }) else {
                    completion(.failure(APIError.tickerNotFound))
                    return
                }
                completion(.success(match))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    //MARK: Search stock while user types the ticker
    ///`.success([])` means nothing on NASDAQ or NYSE matched, which is an answer worth
    ///remembering; `.failure` is anything worth asking again. Completes exactly once.
    ///
    ///Asks the Bullish Square server's /v1/search, which shares each search text between every
    ///user for hours, so "A", "AP", "APP" typed by anyone cost one provider call each. It used
    ///to call yh-finance's auto-complete from the phone with the key built into the app, and
    ///received 8 KB of news and screener data per letter; the server sends only the matches.
    ///(BS-212)
    func searchStocks(ticker: String, completion: @escaping (Result<[Stock], APIError>) -> Void) {
        guard let query = ticker.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            completion(.failure(.invalidURL))
            return
        }
        
        MarketDataServer.authorizedRequest(path: "/v1/search?q=" + query) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                print("Stock search could not reach the server: \(error)")
                completion(.failure(.invalidJSON))
                return
            case .success(let authorized):
                request = authorized
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let data = data,
                      let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidJSON))
                    return
                }
                guard httpResponse.statusCode == 200 else {
                    print("Search server answered \(httpResponse.statusCode) for \(ticker): \(String(data: data, encoding: .utf8) ?? "")")
                    completion(.failure(.invalidJSON))
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                    //Only US-listed stocks can be added, so other exchanges are skipped
                    let stocks = decoded.results
                        .filter { $0.exchange == "NASDAQ" || $0.exchange == "NYSE" }
                        .map { Stock(ticker: $0.symbol, nameTicker: $0.name, exchange: $0.exchange,
                                     stockType: $0.type.isEmpty ? "EQUITY" : $0.type) }
                    completion(.success(stocks))
                } catch let error as NSError {
                    print("Stock search answer could not be read: \(error.localizedDescription)")
                    completion(.failure(.invalidJSON))
                }
            }.resume()
        }
    }
    
    private struct SearchResponse: Decodable {
        let results: [Match]
        
        struct Match: Decodable {
            let symbol: String
            let name: String
            let exchange: String
            let type: String
        }
    }
    
    //MARK: API call for GROUP of stocks with current price
    func getPriceMultipleStocks(tickersGroup: String, timeRange: String, completion: @escaping (Result<[TickersCurrentValues], Error>) -> Void) {
        //Goes through the Bullish Square server instead of straight to RapidAPI. Every device
        //used to spend from one shared monthly quota; the server answers from its cache when
        //another user asked for the same symbols in the last minute. The response is Yahoo's
        //get-spark JSON unchanged, so the parsing below is exactly what it was.
        let symbols = tickersGroup.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tickersGroup
        
        MarketDataServer.authorizedRequest(path: "/v1/spark?symbols=" + symbols + timeRange) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let authorized):
                request = authorized
            }
            
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                if let error = error {
                    print(error)
                    completion(.failure(error))
                    return
                }
            
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
            
                //The server's own refusals carry a reason - app_check_failed, too_many_symbols,
                //upstream_unavailable - worth seeing while App Check is being set up. They parse as
                //a non-empty JSON object, so without this they only ever surfaced as invalidJSON.
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Price server answered \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                    completion(.failure(APIError.invalidJSON))
                    return
                }
            
                //A rate-limit or error body still parses as JSON, so an empty object counts as a failure too
                let decoded = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let json = decoded, !json.isEmpty else {
                    completion(.failure(APIError.invalidJSON))
                    return
                }
            
                var tickersArray : [TickersCurrentValues] = []
                for tickerJSON in json {
                    //Skip malformed entries instead of failing the whole batch
                    guard let tickerDictionary = tickerJSON.value as? [String: Any] else { continue }
                
                    var previousClose = tickerDictionary["chartPreviousClose"] as? Double ?? 0.0
                    //A bar with no trade arrives as JSON null. Reading the raw last element turned
                    //one of those into a price of 0 and a change of -100%, and at five-minute bars
                    //an empty last bar is common, so nulls are dropped and the latest real close wins.
                    let closes = (tickerDictionary["close"] as? [Any] ?? []).compactMap { $0 as? Double }
                    let closePrice = closes.last ?? 0.0
                
                    //A previousClose of 0 made this infinite and pushed it straight into the UI
                    var percentageRounded = 0.0
                    if previousClose > 0 {
                        percentageRounded = ((closePrice * 100) / previousClose) - 100
                    }
                    percentageRounded = Double(round(100*percentageRounded)/100)
                    previousClose = Double(round(100*previousClose)/100)
                
                    let tickerValues = TickersCurrentValues(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose, changePercent: percentageRounded, intradayCloses: closes)
                    tickersArray.append(tickerValues)
                }
            
                guard !tickersArray.isEmpty else {
                    completion(.failure(APIError.invalidJSON))
                    return
                }
            
                let tickersSorted = tickersArray.sorted{ $0.ticker < $1.ticker }
                completion(.success(tickersSorted))
            })
            dataTask.resume()
        }
    }

    //MARK: API call for one stock's analyst consensus
    ///`.success(nil)` means no analyst covers the stock, which is an answer worth remembering;
    ///`.failure` is anything that should be tried again later.
    func getAnalystTarget(ticker: String, completion: @escaping (Result<AnalystTarget?, Error>) -> Void) {
        //Tickers such as BRK-B, ^DJI or BTC-USD. "^" is not allowed unescaped in a path.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        guard let symbol = ticker.addingPercentEncoding(withAllowedCharacters: allowed) else {
            completion(.failure(APIError.invalidTicker))
            return
        }

        MarketDataServer.authorizedRequest(path: "/v1/fundamentals/" + symbol) { result in
            let request: URLRequest
            switch result {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let authorized):
                request = authorized
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.noData))
                    return
                }

                switch httpResponse.statusCode {
                case 200:
                    do {
                        completion(.success(try AnalystTarget.parse(data)))
                    } catch let error as NSError {
                        print("Analyst data for \(ticker) came back in an unexpected shape: \(error.localizedDescription)")
                        completion(.failure(APIError.invalidJSON))
                    }
                case 404:
                    //The server's "no_coverage": an ETF, a coin, or a stock no analyst follows.
                    completion(.success(nil))
                default:
                    print("Analyst server answered \(httpResponse.statusCode) for \(ticker): \(String(data: data, encoding: .utf8) ?? "")")
                    completion(.failure(APIError.invalidJSON))
                }
            }.resume()
        }
    }

    //MARK: API call for general markets
    func getPriceGeneralMarkets(completion: @escaping([GeneralMarkets]?, Int) -> Void) {
        let headers = [
            "x-api-key": KeysStocksAPI.generalMarketKey,
            "x-rapidapi-host": KeysStocksAPI.generalMarketHost
        ]
        
        let urlString = KeysStocksAPI.generalBaseURL
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if let error = error {
                print(error)
                completion(nil, 0)
                return
            }
            
            guard let data = data else {
                completion(nil, 0)
                return
            }
            
            //data, the quoteResponse lookup and every field inside result were force unwrapped
            //or force cast. This runs from SceneDelegate on every cold start, so a rate-limit
            //body crashed the launch before the loop was even reached.
            guard let quotes = (try? JSONDecoder().decode(GeneralMarketsResponse.self, from: data))?
                .quoteResponse?.result else {
                completion(nil, 0)
                return
            }
            
            var marketsValues = [GeneralMarkets]()
            var timeStamp = 0
            
            for quote in quotes {
                //Skip an index missing anything displayed, rather than trapping on it
                guard let ticker = quote.symbol,
                      let shortName = quote.shortName,
                      let marketPrice = quote.regularMarketPrice,
                      let changePercentage = quote.regularMarketChangePercent else { continue }
                
                timeStamp = quote.regularMarketTime ?? timeStamp
                
                marketsValues.append(GeneralMarkets(indexTicker: ticker,
                                                    indexName: shortName,
                                                    indexPrice: marketPrice,
                                                    changePercentage: Double(round(100*changePercentage)/100)))
            }
            
            //The request always asks for the same four indices, so nothing usable means the
            //response shape changed. Report it rather than showing an empty Markets screen.
            guard !marketsValues.isEmpty else {
                completion(nil, 0)
                return
            }
            
            completion(marketsValues, timeStamp)
        })
        dataTask.resume()
    }
}
