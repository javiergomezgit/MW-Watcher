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
    func getPriceSingleTicker(ticker: String, timeRange: String, completion: @escaping (Result<TickersCurrentValues, Error>) -> Void) {
        let headers = [
            "x-rapidapi-key": KeysStocksAPI.apiCurrentPriceKey,
            "x-rapidapi-host": KeysStocksAPI.apiCurrentPriceHost
        ]
        
        let url = KeysStocksAPI.apiCurrentPriceBaseURL + ticker + timeRange
        
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if let error = error {
                print(error)
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            //A rate-limit or error body still parses as JSON, so an empty object counts as a failure too
            let decoded = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let json = decoded, !json.isEmpty else {
                completion(.failure(APIError.invalidJSON))
                return
            }
            
            for tickerJSON in json {
                //Skip entries that aren't a ticker payload, e.g. {"message": "rate limited"}
                guard let tickerDictionary = tickerJSON.value as? [String: Any] else { continue }
                
                var previousClose = tickerDictionary["chartPreviousClose"] as? Double ?? 0.0
                let closePriceArray = tickerDictionary["close"] as? [Any]
                let closePrice = closePriceArray?.last as? Double ?? 0.0
                
                //A previousClose of 0 made this infinite and pushed it straight into the UI
                var percentageRounded = 0.0
                if previousClose > 0 {
                    percentageRounded = ((closePrice * 100) / previousClose) - 100
                }
                
                percentageRounded = Double(round(100*percentageRounded)/100)
                previousClose = Double(round(100*previousClose)/100)
                
                let tickerCurrentValues = TickersCurrentValues(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose, changePercent: percentageRounded)
                completion(.success(tickerCurrentValues))
                return
            }
            
            //Nothing in the response was a usable ticker payload
            completion(.failure(APIError.tickerNotFound))
        })
        dataTask.resume()
    }
    
    //MARK: Search stock while user types the ticker
    func searchStocks(ticker: String, completion: @escaping ([Stock]?, APIError?) -> Void) {
        let headers = [
            "X-RapidAPI-Key": KeysStocksAPI.searchWhileTypeKey,
            "X-RapidAPI-Host": KeysStocksAPI.searchWhileTypeHost
        ]
        let query = ticker
        let urlString = "\(KeysStocksAPI.searchWhileTypeBaseURL)\(query)&region=US"
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
        dump (request.url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) { data, _, error in
            if error != nil {
                completion(nil, .invalidJSON)
                return
            }
            
            guard let data = data else {
                completion(nil, .invalidJSON)
                return
            }
            
            do {
                let json = try JSON(data: data)
                print (json)
                var stocks = [Stock]()
                for (key, subJson):(String, JSON) in json {
                    if key == "quotes" {
                        print (key.count) //count 6
                        print (key)
                        for (_, subSubJSON):(String, JSON) in subJson {
                            if let exchange = subSubJSON.object as? [String: Any] {
                                if exchange["exchDisp"] as? String == "NASDAQ" || exchange["exchDisp"] as? String == "NYSE" {
                                    if let symbolDictionary = subSubJSON.object as? [String: Any] {
                                        let symbol = symbolDictionary["symbol"] as? String
                                        let shortName = symbolDictionary["shortname"] as? String
                                        let longName = symbolDictionary["longname"] as? String //Stores the long name of the stock
                                        let name = shortName ?? longName ?? "N/A"
                                        let stockType = symbolDictionary["quoteType"] as? String
                                        let exchange = symbolDictionary["exchDisp"] as? String
                                        let stock = Stock(ticker: symbol!, nameTicker: name, exchange: exchange!, stockType: stockType!)
                                        stocks.append(stock)
                                    }
                                }
                            }
                        }
                    }
                }
                if stocks.count == 0 {
                    print ("couldnt find any stock related")
                    completion(nil, .tickerNotFound)
                }
                print (stocks)
                completion(stocks, nil)
            } catch {
                completion(nil, .invalidJSON)
            }
        }
        task.resume()
    }
    
    //MARK: API call for GROUP of stocks with current price
    func getPriceMultipleStocks(tickersGroup: String, timeRange: String, completion: @escaping (Result<[TickersCurrentValues], Error>) -> Void) {
        let headers = [
            "x-rapidapi-key": KeysStocksAPI.groupStocksPriceKey,
            "x-rapidapi-host": KeysStocksAPI.groupStocksPriceHost
        ]
        
        let url = KeysStocksAPI.groupStocksPriceBaseURL + tickersGroup + timeRange
        
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if let error = error {
                print(error)
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
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
                let closePriceArray = tickerDictionary["close"] as? [Any]
                let closePrice = closePriceArray?.last as? Double ?? 0.0
                
                //A previousClose of 0 made this infinite and pushed it straight into the UI
                var percentageRounded = 0.0
                if previousClose > 0 {
                    percentageRounded = ((closePrice * 100) / previousClose) - 100
                }
                percentageRounded = Double(round(100*percentageRounded)/100)
                previousClose = Double(round(100*previousClose)/100)
                
                let tickerValues = TickersCurrentValues(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose, changePercent: percentageRounded)
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
