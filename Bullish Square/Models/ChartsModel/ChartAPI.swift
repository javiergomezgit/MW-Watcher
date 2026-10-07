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
        case noData
    }
    
    //MARK: API call for STOCKS chart
    ///Input: 1day, TICKER
    ///Output: -> ["timeStamp": "20-10-2021, "open":34,5, "high":36, "low":32.2, "close":33.1,"volume":233343]
    ///Returns a plain Result. This used to be a custom ResultStock whose only purpose was to
    ///carry the exchange name alongside the values, and the endpoint stopped sending that name
    ///when the chart moved to the v2 history API, so the app no longer shows an exchange.
    public func getStockValues(intervalTime: String, symbol: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        
        let headers = [
            "X-RapidAPI-Host": KeysChartsAPI.getStockApiHost,
            "X-RapidAPI-Key": KeysChartsAPI.getStockApiKey
        ]
        
        let request = NSMutableURLRequest(
            url: NSURL(string: KeysChartsAPI.getStockBaseUrl + symbol + "&interval=" + intervalTime )! as URL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 10.0)
        
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                
                let json = try JSON(data: data)
                
                var valuesStock: [ValueStock] = []
                
                for (key, subJson):(String, JSON) in json {
                    if key == "body" {
                        for (_, subSubJSON):(String, JSON) in subJson {
                            let dateTime =  subSubJSON["timestamp_unix"].double
                            let open    =   subSubJSON["open"].double
                            let high    =   subSubJSON["high"].double
                            let low     =   subSubJSON["low"].double
                            let close   =   subSubJSON["close"].double
                            let volume  =   subSubJSON["volume"].double
                            
                            guard let dateTime = dateTime,
                                  let open = open,
                                  let high = high,
                                  let low = low,
                                  let close = close,
                                  let volume = volume else { continue }
                            
                            let value = ValueStock(start_timestamp: dateTime, open: open, high: high, low: low, close: close, volume: volume)
                            valuesStock.append(value)
                        }
                    }
                }
                let filteredValues = valuesStock.filter { $0.close != 0 }
                let sortedValues = filteredValues.sorted(by: { $0.start_timestamp > $1.start_timestamp })
                valuesStock.removeAll()
                for (index, valueStock) in sortedValues.enumerated() {
                    if index <= 59 {
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
    
    
    //MARK: API Call for chart for general markets
    ///Input: 1day, TICKER
    ///Output: -> ["timeStamp": "20-10-2021, "open":34,5, "high":36, "low":32.2, "close":33.1,"volume":233343]
    func getMarketValues(intervalTime: String, symbol: String, completion: @escaping(Result<[ValueStock], Error>) -> Void) {
        
        let headers = [
            "X-RapidAPI-Host": KeysChartsAPI.getGeneralMarketApiHost,
            "X-RapidAPI-Key": KeysChartsAPI.getGeneralMarketApiKey
        ]
        
        //Only escape a leading ^. The previous version replaced the first character
        //unconditionally, which mangled plain symbols and trapped on an empty string.
        let symbolFixed = symbol.hasPrefix("^") ? "%5E" + symbol.dropFirst() : symbol
        
        let urlString = "\(KeysChartsAPI.getGeneralMarketBaseUrl)\(symbolFixed)&interval=\(intervalTime)&diffandsplits=false"
        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
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
            
            do {
                
                let json = try JSON(data: data)
                
                var valuesStock: [ValueStock] = []
                
                for (key, subJson):(String, JSON) in json {
                    if key == "body" {
                        for (_, subSubJSON):(String, JSON) in subJson {
                            //Skip incomplete candles rather than trapping on them. Intraday
                            //series routinely carry nulls across pre/post-market gaps.
                            //getStockValues already guarded this way; this function did not.
                            guard let dateTime = subSubJSON["date_utc"].double,
                                  let open = subSubJSON["open"].double,
                                  let high = subSubJSON["high"].double,
                                  let low = subSubJSON["low"].double,
                                  let close = subSubJSON["close"].double,
                                  let volume = subSubJSON["volume"].double else { continue }
                            
                            let value = ValueStock(start_timestamp: dateTime, open: open, high: high, low: low, close: close, volume: volume)
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
                completion(.success(valuesStock))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    //MARK: The Markets tab's three index lines, from the Bullish Square server
    ///Today's session for the Dow, S&P 500 and Nasdaq as % change from the previous close,
    ///keyed by symbol. A symbol missing from the answer is simply absent.
    ///
    ///One request for all three, answered from the server's 60 s cache shared by every user.
    ///This replaced three mboum calls per user per refresh, which used up mboum's 500-a-month
    ///plan and left the chart empty for everyone (BS-228). `range=1d` is the latest session,
    ///so the chart also shows the last session before the open and at weekends; the old
    ///"after 6:30 local" filter assumed Pacific time and showed nothing then.
    func getMajorMarketsLines(completion: @escaping (Result<[String: [MarketsCandles]], Error>) -> Void) {
        MarketDataServer.authorizedRequest(path: "/v1/spark?symbols=%5EDJI,%5EGSPC,%5EIXIC&interval=5m&range=1d") { result in
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
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Markets server answered \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                    completion(.failure(APIError.invalidJSON))
                    return
                }
                guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    completion(.failure(APIError.invalidJSON))
                    return
                }
                completion(.success(Self.marketsLines(from: json)))
            }.resume()
        }
    }
    
    ///Yahoo's get-spark shape: per symbol, parallel `timestamp` and `close` arrays plus
    ///`chartPreviousClose`. Each close becomes its % change from that previous close, which
    ///is what the chart plots. A null close (a bar with no trade) is skipped with its
    ///timestamp, and a symbol without a usable previous close is left out rather than
    ///divided by zero.
    static func marketsLines(from json: [String: Any]) -> [String: [MarketsCandles]] {
        var lines: [String: [MarketsCandles]] = [:]
        for (symbol, value) in json {
            guard let series = value as? [String: Any],
                  let previousClose = series["chartPreviousClose"] as? Double, previousClose > 0,
                  let timestamps = series["timestamp"] as? [Double],
                  let closes = series["close"] as? [Any] else { continue }
            
            var candles: [MarketsCandles] = []
            for (timestamp, rawClose) in zip(timestamps, closes) {
                guard let close = rawClose as? Double, close > 0 else { continue }
                let change = ((close * 100) / previousClose) - 100
                //Only the close is plotted; open, high and low carry the same value.
                candles.append(MarketsCandles(start_timestamp: timestamp, open: change, high: change, low: change, close: change))
            }
            lines[symbol] = candles
        }
        return lines
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
                    
                    guard let tickerDict = tickerJSON.value as? [String: Any],
                          let previousClose = tickerDict["chartPreviousClose"] as? Double,
                          let rawPrices = tickerDict["close"] as? [Any],
                          let arrayTimeStamps = tickerDict["timestamp"] as? [Double] else { continue }
                    
                    let arrayPrices: [Double] = rawPrices.compactMap { item in
                        guard let price = item as? Double, price > 0 else { return nil }
                        return price
                    }
                    
                    guard !arrayPrices.isEmpty,
                          let currentPrice = arrayPrices.last,
                          let basePrice = arrayPrices.first else { continue }
                    
                    var pricesAndTimes = [MarketsClosedPrices]()
                    for (index, closePrice) in arrayPrices.enumerated() {
                        let changePercentage = ((closePrice * 100) / basePrice) - 100
                        let percentageRounded = Double(round(100*changePercentage)/100)
                        
                        guard index < arrayTimeStamps.count else { break }
                        let priceTime = MarketsClosedPrices(timeStamp: arrayTimeStamps[index], close: percentageRounded)
                        pricesAndTimes.append(priceTime)
                    }
                    
                    //A previousClose of 0 would make this infinite. basePrice above is safe,
                    //the compactMap already drops any price that is not greater than zero.
                    let changePercentage = previousClose > 0 ? ((currentPrice * 100) / previousClose) - 100 : 0.0
                    let percentageRounded = Double(round(100*changePercentage)/100)

                    let tickerValue = PerformersPrices(ticker: tickerJSON.key, changePercentage: percentageRounded, currentPrice: currentPrice, tickerPerformer: pricesAndTimes)
                    
                    marketsValues.append(tickerValue)
                }
                completion(marketsValues)
            }
        })
        dataTask.resume()
    }
    
}
