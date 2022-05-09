//
//  ChartsAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/6/22.
//

import Foundation
import SwiftyJSON
//import UIKit

final class ChartsAPI {
    static let shared = ChartsAPI()
    
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
        
        struct Constant {
            static let apiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
            static let apiHost = "yahoo-finance15.p.rapidapi.com"
            static let baseUrl = "https://yahoo-finance15.p.rapidapi.com/api/yahoo/hi/history/"
            static let endpoint = "?diffandsplits=true"
        }
      
        let headers = [
            "X-RapidAPI-Host": Constant.apiHost,
            "X-RapidAPI-Key": Constant.apiKey
        ]

        let request = NSMutableURLRequest(
            url: NSURL(string: Constant.baseUrl + symbol + "/" + intervalTime + Constant.endpoint)! as URL,
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
                    if key == "items" {
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
            "X-RapidAPI-Host": "mboum-finance.p.rapidapi.com",
            "X-RapidAPI-Key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
        ]
        
        let symbolFixed = symbol.replacingCharacters(in: ...symbol.startIndex, with: "%5E")
        
        let urlString = "https://mboum-finance.p.rapidapi.com/hi/history?symbol=\(symbolFixed)&interval=\(intervalTime)&diffandsplits=false"
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
                    if key == "items" {
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
}
