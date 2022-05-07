//
//  StocksAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation
import SwiftyJSON
import UIKit

final class StocksAPI {
    static let shared = StocksAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
    }
        
    //MARK: API call for search/add of single stock
    ///Input: ticker,
    ///output:  -> "TICKER" : ["Name Company", 344.3, 320.2, 2334533, UIImage]
    func getPriceSingleStock(tickerSingle: String, completion: @escaping (Result<Tickers, Error>) -> Void) {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "stock-data-yahoo-finance-alternative.p.rapidapi.com"
        ]
        
        let urlString = "https://stock-data-yahoo-finance-alternative.p.rapidapi.com/v6/finance/quote?symbols=" + tickerSingle
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
                            let marketPrice = tickerValue["regularMarketPrice"] as! Double
                            let previousPrice = tickerValue["regularMarketPreviousClose"] as! Double
                            let nameCompany = tickerValue["longName"] as! String
                            let volume = tickerValue["regularMarketVolume"] as! Double
                            
                            self.getLogoStock(ticker: tickerSingle) { result in
                                switch result {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success(let imageCompany):
                                    let values = Tickers(ticker: tickerSingle, tickerValues: TickerValues(nameCompany: nameCompany, marketPrice: marketPrice, previousPrice: previousPrice, volume: volume, imageCompany: imageCompany))
                                    completion(.success(values))
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
            "X-RapidAPI-Host": "twelve-data1.p.rapidapi.com",
            "X-RapidAPI-Key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
        ]
                
        let urlString = "https://twelve-data1.p.rapidapi.com/logo?symbol=\(ticker)"
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
    
    
    //MARK: API call for GROUP of stocks with current price
    ///Input: no,more,than,ten,merged,tickers
    ///output:  ->  "indexTicker": "TICKER", "indexName": "Index Name", "indexPrice": 344.4, "changePercentage": 4.5, "exchange": "Exchange Source"
    func getPriceMultipleStocks(tickersGroup: String, timeRange: String, completion: @escaping (Result<[TickersPriceGroup], Error>) -> Void) {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
        ]
        
        let url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + tickersGroup + timeRange
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
                
                var tickersWithoutSorting : [TickersPriceGroup] = []
                for tickerJSON in json! {
                    print (tickerJSON.value) //json
                    print (tickerJSON.key) //ticker
                    
                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray!.last as! Double
                    
                    let percentage = 3.4
                    
                    let tickerValues = TickersPriceGroup(ticker: tickerJSON.key, tickerPrices: TickerPrices(closePrice: closePrice, previousClosePrice: previousClose, changePercentagePrice: percentage))
                    tickersWithoutSorting.append(tickerValues)
                }
                
                let tickersSorted = tickersWithoutSorting.sorted{ $0.ticker < $1.ticker }
                completion(.success(tickersSorted))
            }
        })
        dataTask.resume()
    }
    
    
    //MARK: API call for general markets
    ///output:  ->  ["TICKER" : [344.3, 320.2, 4.5]]
    func getPriceGeneralMarkets(completion: @escaping([GeneralMarkets]?) -> Void) {
        let headers = [
            "x-api-key": "oFf1Q9pDzb6LovcGuCciz1ngVdnCN04J1FGi2fLa",
            "x-rapidapi-host": "yfapi.net"
        ]

        let urlString = "https://yfapi.net/v6/finance/quote?region=US&lang=en&symbols=%5EDJI%2C%5EGSPC%2C%5EIXIC%2C%5EW5000%2C%5ERUA%2C%5ESP400%2C%5ERUT%2C%5EVIX"
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
                print (json!)
                
                let resultJSON = json?["quoteResponse"] as? [String: Any]
                
                if let resultArray = resultJSON!["result"] as? [Any] {
                    
                    var marketsValues = [GeneralMarkets]()
                    for tickerJSON in resultArray {
                        
                        let tickerDictionary = tickerJSON as? [String: Any]
                        
                        let marketPrice = tickerDictionary!["regularMarketPrice"] as! Double
                        let changePercentage = tickerDictionary!["regularMarketChangePercent"] as! Double
                        let ticker = tickerDictionary!["symbol"] as! String
                        let exchange = tickerDictionary!["exchange"] as! String
                        let shortName = tickerDictionary!["shortName"] as! String
                        
                        let marketIndex = GeneralMarkets(indexTicker: ticker, indexName: shortName, indexPrice: marketPrice, changePercentage: changePercentage, exchange: exchange)
                        marketsValues.append(marketIndex)
                    }
                    marketsValues = marketsValues.sorted{ $0.changePercentage < $1.changePercentage }
                    completion(marketsValues)
                } else {
                    completion(nil)
                }
            }
        })
        dataTask.resume()
    }

    
    
    

    

    
}
