//
//  StocksAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation
import SwiftyJSON

final class StocksAPI {
    static let shared = StocksAPI()
    
    private struct Constant {
        static let apiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
        static let apiHost = "alpha-vantage.p.rapidapi.comY"
        static let baseUrl = "https://alpha-vantage.p.rapidapi.com/query?"
        static let endpoint = "cryptocurrency/quotes/latest"
        static var functionTime = "&function=TIME_SERIES_INTRADAY&"
        static let options = "&datatype=json&output_size=full"
        static var intervalTime = "15min"
    }
    private init() {}

    
    enum APIError: Error {
        case invalidURL
    }
    
    public func getStockValues(interval: String, symbol: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        
        switch interval {
        case "15min":
            Constant.intervalTime = "interval=15min"
            Constant.functionTime = "&function=TIME_SERIES_INTRADAY&"
        case "60min":
            Constant.intervalTime = "interval=60min"
            Constant.functionTime = "&function=TIME_SERIES_INTRADAY&"
        case "18000":
            Constant.functionTime = "&function=TIME_SERIES_DAILY"
        case "86400":
            Constant.functionTime = "&function=TIME_SERIES_DAILY"
        case "week":
            Constant.functionTime = "&function=TIME_SERIES_WEEKLY"
        case "month":
            Constant.functionTime = "&function=TIME_SERIES_MONTHLY"
        default:
            Constant.functionTime = "&function=TIME_SERIES_INTRADAY&"
        }
        let headers = [
            "X-RapidAPI-Host": Constant.apiHost,
            "X-RapidAPI-Key": Constant.apiKey
        ]

        let request = NSMutableURLRequest(url: NSURL(string:
                                                     Constant.baseUrl +
                                                     Constant.intervalTime +
                                                     Constant.functionTime +
                                                     "symbol=" +
                                                     symbol +
                                                     Constant.options)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
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
                   // Do something you want
                    if key != "Meta Data" {

                    //print (key)
                    //print (subJson)
//                        var enumerated = 0
                        for (key, subSubJSON):(String, JSON) in subJson {
                            //print (key)
                            //print (subSubJSON)
                           
                            let dateTime = key
                            let open = subSubJSON["1. open"].stringValue
                            let high = subSubJSON["2. high"].stringValue
                            let low = subSubJSON["3. low"].stringValue
                            let close = subSubJSON["4. close"].stringValue
                            let volume = subSubJSON["5. volume"].stringValue
                             
                            let value = ValueStock(start_timestamp: dateTime, open: open, high: high, low: low, close: close, volume: volume)
                            valuesStock.append(value)
                            
//                            if enumerated <= 59 {
//                                enumerated += 1
//                                //print (subSubJSON)
//                            } else {
//                                break
//                            }
                        }
                        
                        //print (valuesStock)
                    }
                }
                let sortedValues = valuesStock.sorted(by: { $0.start_timestamp < $1.start_timestamp }) //.sorted(by: { $0.start_timestamp < $1.start_timestamp })

                valuesStock.removeAll()
                for (index, valueStock) in sortedValues.enumerated() {
                    if index <= 59 {
                        valuesStock.append(valueStock)
                    }
                }
                
                completion(.success(sortedValues))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
