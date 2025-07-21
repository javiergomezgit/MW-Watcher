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
                                    let tickerFeatures = TickersFeatures(ticker: tickerSingle, nameTicker: nameCompany!, imageTicker: imageCompany)
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
                return
            }
            
            do {
                let json = try JSON(data: data)
                var downloadedImage = UIImage(named: "mw-logo")!
                for (key, subJson):(String, JSON) in json {
                    
                    if key == "url" {
                        guard let urlString = subJson.string else {
                            return
                        }
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: urlString)
                    }
                }
                completion(.success(downloadedImage))
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
        var json: [String: Any]? = [:]
        
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
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
                    completion(.failure("JSON is Empty" as! Error))
                }
                
                for tickerJSON in json! {
                    print (tickerJSON.value) //json
                    print (tickerJSON.key) //ticker
                    
                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    var previousClose = tickerDictionary!["chartPreviousClose"] as? Double ?? 0.0
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray!.last as? Double ?? 0.0 //TODO: validate when is empty
                    
                    let percentageChange = (closePrice * 100) / previousClose
                    var percentageRounded = 0.0
                    percentageRounded = percentageChange - 100
                    
                    percentageRounded = Double(round(100*percentageRounded)/100)
                    previousClose = Double(round(100*previousClose)/100)
                    
                    let tickerCurrentValues = TickersCurrentValues(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose, changePercent: percentageRounded)
                    completion(.success(tickerCurrentValues))
                    break
                }
            }
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
                                        _ = symbolDictionary["longname"] as? String //Stores the long name of the stock
                                        let stock = Stock(ticker: symbol!, nameTicker: shortName!)
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
        var json: [String: Any]? = [:]
        
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
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
                    completion(.failure("JSON is Empty" as! Error))
                }
                
                var tickersArray : [TickersCurrentValues] = []
                for tickerJSON in json! {
                    print (tickerJSON.value) //json
                    print (tickerJSON.key) //ticker
                    
                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    var previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray!.last as! Double
                    
                    let percentageChange = (closePrice * 100) / previousClose
                    var percentageRounded = 0.0
                    percentageRounded = percentageChange - 100
                    percentageRounded = Double(round(100*percentageRounded)/100)
                    previousClose = Double(round(100*previousClose)/100)
                    
                    let tickerValues = TickersCurrentValues(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose, changePercent: percentageRounded)
                    tickersArray.append(tickerValues)
                }
                let tickersSorted = tickersArray.sorted{ $0.ticker < $1.ticker }
                completion(.success(tickersSorted))
            }
        })
        dataTask.resume()
    }

    //MARK: API call for general markets
    func getPriceGeneralMarkets(completion: @escaping([GeneralMarkets]?) -> Void) {
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
            if (error != nil) {
                completion(nil)
            } else {
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                print (json as Any)
                
                let resultJSON = json?["quoteResponse"] as? [String: Any]
                
                if let resultArray = resultJSON!["result"] as? [Any] {
                    
                    var marketsValues = [GeneralMarkets]()
                    for tickerJSON in resultArray {
                        
                        let tickerDictionary = tickerJSON as? [String: Any]
                        
                        let marketPrice = tickerDictionary!["regularMarketPrice"] as! Double
                        let changePercentage = tickerDictionary!["regularMarketChangePercent"] as! Double
                        let ticker = tickerDictionary!["symbol"] as! String
                        let shortName = tickerDictionary!["shortName"] as! String
                        
                        let percentageRounded = Double(round(100*changePercentage)/100)
                        
                        let marketIndex = GeneralMarkets(indexTicker: ticker, indexName: shortName, indexPrice: marketPrice, changePercentage: percentageRounded)
                        marketsValues.append(marketIndex)
                    }
                    //                    marketsValues = marketsValues.sorted{ $0.changePercentage < $1.changePercentage }
                    completion(marketsValues)
                } else {
                    completion(nil)
                }
            }
        })
        dataTask.resume()
    }
}
