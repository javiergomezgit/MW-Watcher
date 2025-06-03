//
//  ChartAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/3/25.
//


import Foundation
import SwiftyJSON
//import UIKit

final class ChartAPI {
    static let shared = ChartAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
    }
    
    //MARK: API call for STOCKS chart
    ///Input: 1day, TICKER
    ///Output: -> ["timeStamp": "20-10-2021, "open":34,5, "high":36, "low":32.2, "close":33.1,"volume":233343]
    public func getStockValues(intervalTime: String, symbol: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        
        let headers = [
            "X-RapidAPI-Host": KeysChartsAPI.getStockApiHost,
            "X-RapidAPI-Key": KeysChartsAPI.getStockApiKey
        ]
        
        let request = NSMutableURLRequest(
            url: NSURL(string: KeysChartsAPI.getStockBaseUrl + symbol + "/" + intervalTime + KeysChartsAPI.getStockEndpoint)! as URL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 10.0)
        
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
                
                var valuesStock: [ValueStock] = []
                
                for (key, subJson):(String, JSON) in json {
                    if key == "body" {
                        for (_, subSubJSON):(String, JSON) in subJson {
                            let dateTime =  subSubJSON["date_utc"].double
                            let open    =   subSubJSON["open"].double
                            let high    =   subSubJSON["high"].double
                            let low     =   subSubJSON["low"].double
                            let close   =   subSubJSON["close"].double
                            let volume  =   subSubJSON["volume"].double
                            
                            let value = ValueStock(start_timestamp: dateTime!, open: open!, high: high!, low: low!, close: close!, volume: volume!)
                            valuesStock.append(value)
                        }
                    }
                }
                let sortedValues = valuesStock.sorted(by: { $0.start_timestamp > $1.start_timestamp })
                valuesStock.removeAll()
                for (index, valueStock) in sortedValues.enumerated() {
                    if index <= 59 {
                        valuesStock.append(valueStock)
                    }
                }
                
                valuesStock.reverse()
                
                dump (valuesStock)
                
                completion(.success(valuesStock))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    
    //MARK: API Call for chart for general markets
    ///Input: 1day, TICKER
    ///Output: -> ["timeStamp": "20-10-2021, "open":34,5, "high":36, "low":32.2, "close":33.1,"volume":233343]
    func getMarketValues(intervalTime: String, symbol: String, completion: @escaping(Result<[ValueStock], Error>) -> Void) {
        
        let headers = [
            "X-RapidAPI-Host": KeysChartsAPI.getGeneralMarketApiHost,
            "X-RapidAPI-Key": KeysChartsAPI.getGeneralMarketApiKey
        ]
        
        let symbolFixed = symbol.replacingCharacters(in: ...symbol.startIndex, with: "%5E")
        
        let urlString = "\(KeysChartsAPI.getGeneralMarketBaseUrl)\(symbolFixed)&interval=\(intervalTime)&diffandsplits=false"
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
                
                var valuesStock: [ValueStock] = []
                
                for (key, subJson):(String, JSON) in json {
                    if key == "body" {
                        for (_, subSubJSON):(String, JSON) in subJson {
                            let dateTime =  subSubJSON["date_utc"].double
                            let open    =   subSubJSON["open"].double
                            let high    =   subSubJSON["high"].double
                            let low     =   subSubJSON["low"].double
                            let close   =   subSubJSON["close"].double
                            let volume  =   subSubJSON["volume"].double
                            
                            let value = ValueStock(start_timestamp: dateTime!, open: open!, high: high!, low: low!, close: close!, volume: volume!)
                            valuesStock.append(value)
                        }
                    }
                }
                let sortedValues = valuesStock.sorted(by: { $0.start_timestamp > $1.start_timestamp })
                valuesStock.removeAll()
                for (index, valueStock) in sortedValues.enumerated() {
                    if index <= 59 {
                        valuesStock.append(valueStock)
                    }
                }
                
                valuesStock.reverse()
                dump (valuesStock)
                completion(.success(valuesStock))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func getMajorMarketsValues(symbol: String, completion: @escaping(Result<[MarketsCandles], Error>) -> Void) {
        
        let headers = [
            "X-RapidAPI-Host": KeysChartsAPI.getMajorsMarketsApiHost,
            "X-RapidAPI-Key": KeysChartsAPI.getMajorsMarketsApiKey
        ]
        
        let intervalTime = "5m"
        
        let symbolFixed = symbol.replacingCharacters(in: ...symbol.startIndex, with: "%5E")
        
        let urlString = "\(KeysChartsAPI.getMajorsMarketsBaseUrl)\(symbolFixed)&interval=\(intervalTime)&diffandsplits=false"
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
                
                let date = Date()
                let calendar = Calendar.current
                let day = calendar.component(.day, from: date)
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                let zone = TimeZone.current
                
                var dateComponents = DateComponents()
                dateComponents.year = year
                dateComponents.month = month
                dateComponents.day = day
                dateComponents.timeZone = zone
                dateComponents.hour = 6
                dateComponents.minute = 30
                dateComponents.second = 0
                
                let userCalendar = Calendar(identifier: .gregorian)
                let someDateTime = userCalendar.date(from: dateComponents)
                let dateFormatter = DateFormatter()
                dateFormatter.timeZone = zone
                let timeStartedMarket = Int(someDateTime!.timeIntervalSince1970)
                
                let json = try JSON(data: data)
                
                var valuesStock: [MarketsCandles] = []
                var previousClose = 0.0
                
                for (key, subJson):(String, JSON) in json {
                    if key == "meta" {
                        previousClose = subJson["previousClose"].double!
                        dump(previousClose)
                        break
                    }
                }
                
                for (key, subJson):(String, JSON) in json {
                    if key == "body" {
                        for (_, subSubJSON):(String, JSON) in subJson {
                            let dateTime =  subSubJSON["date_utc"].double
                            let open    =   subSubJSON["open"].double
                            let high    =   subSubJSON["high"].double
                            let low     =   subSubJSON["low"].double
                            let closePrice   =   subSubJSON["close"].double
                            
                            var close = 0.0
                            
                            if Int(dateTime!) > timeStartedMarket {
                                if closePrice != 0.0 {
                                    close = ((closePrice! * 100) / previousClose) - 100
                                    let value = MarketsCandles(start_timestamp: dateTime!, open: open!, high: high!, low: low!, close: close)
                                    valuesStock.append(value)
                                }
                            }
                        }
                        break
                    }
                }
                let valuesStockSorted = valuesStock.sorted(by: { $0.start_timestamp > $1.start_timestamp })
                valuesStock.removeAll()
                for (index, valueStock) in valuesStockSorted.enumerated() {
                    if index <= 78 {
                        valuesStock.append(valueStock)
                    }
                }
                valuesStock.reverse()
                
                completion(.success(valuesStock))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    

    //MARK: API call for general markets and watchlist
    func getPricesMarketsAndWatchlist(tickersWatchlist: String, timeRange: String, completion: @escaping([PerformersPrices]?) -> Void) {
        let headers = [
            "x-api-key": KeysChartsAPI.getGeneralWatchkey,
            "x-rapidapi-host": KeysChartsAPI.getGeneralWatchHost
        ]
        let urlString = "\(KeysChartsAPI.getGeneralWatchBaseUrl)\(timeRange)&symbols=%5EDJI%2C%5EGSPC%2C%5EIXIC%2C%5EVIX%2C\(tickersWatchlist)"
        print (urlString)
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
                
                guard let arrayJSON = json else {
                    return
                }
                
                var marketsValues = [PerformersPrices]()
                for tickerJSON in arrayJSON {
                    print (tickerJSON)

                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    
                    let arrayPrices = tickerDictionary!["close"] as! [Double]
                    let arrayTimeStamps = tickerDictionary!["timestamp"] as! [Double]
                    
                    let currentPrice = arrayPrices.last
                    let basePrice = arrayPrices.first
                    var pricesAndTimes = [MarketsClosedPrices]()
                    for (index, closePrice) in arrayPrices.enumerated() {
                        let changePercentage = ((closePrice * 100) / basePrice!) - 100
                        let percentageRounded = Double(round(100*changePercentage)/100)
                        
                        let priceTime = MarketsClosedPrices(timeStamp: arrayTimeStamps[index], close: percentageRounded)
                        pricesAndTimes.append(priceTime)
                    }
                    
                    let changePercentage = ((currentPrice! * 100) / previousClose) - 100
                    let percentageRounded = Double(round(100*changePercentage)/100)
                    
                    let tickerValue = PerformersPrices(ticker: tickerJSON.key, changePercentage: percentageRounded, currentPrice: currentPrice!, tickerPerformer: pricesAndTimes)
                    
                    marketsValues.append(tickerValue)
                }
                completion(marketsValues)
            }
        })
        dataTask.resume()
    }
    
}
