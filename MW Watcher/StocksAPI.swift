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
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case tickerNotFound
        case invalidJSON
        case invalidTicker
    }
    
    //MARK: API call for STOCKS chart
    public func getStockValues(interval: String, symbol: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        
        struct Constant {
            static let apiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
            static let apiHost = "alpha-vantage.p.rapidapi.com"
            static let baseUrl = "https://alpha-vantage.p.rapidapi.com/query?"
            static let endpoint = "cryptocurrency/quotes/latest"
            static var functionTime = ""
            static let options = "&datatype=json&output_size=compact"
            static var intervalTime = ""
        }
        
        switch interval {
        case "15min":
            Constant.intervalTime = "interval=15min"
            Constant.functionTime = "&function=TIME_SERIES_INTRADAY&"
        case "60min":
            Constant.intervalTime = "interval=60min"
            Constant.functionTime = "&function=TIME_SERIES_INTRADAY&"
        case "18000":
            Constant.functionTime = "function=TIME_SERIES_DAILY_ADJUSTED&"
            Constant.intervalTime = ""
        case "86400":
            Constant.functionTime = "function=TIME_SERIES_DAILY_ADJUSTED&"
            Constant.intervalTime = ""
        case "week":
            Constant.functionTime = "function=TIME_SERIES_WEEKLY_ADJUSTED&"
            Constant.intervalTime = ""
        case "month":
            Constant.functionTime = "function=TIME_SERIES_MONTHLY_ADJUSTED&"
            Constant.intervalTime = ""
        default:
            Constant.functionTime = "function=TIME_SERIES_INTRADAY_ADJUSTED&"
            Constant.intervalTime = ""
        }
        let headers = [
            "X-RapidAPI-Host": Constant.apiHost,
            "X-RapidAPI-Key": Constant.apiKey
        ]

        let request = NSMutableURLRequest(
            url: NSURL(string: Constant.baseUrl + Constant.intervalTime + Constant.functionTime + "symbol=" + symbol + Constant.options)! as URL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 10.0)
        
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
                    if key != "Meta Data" {
                        for (key, subSubJSON):(String, JSON) in subJson {
                            let dateTime = key
                            let open = subSubJSON["1. open"].stringValue
                            let high = subSubJSON["2. high"].stringValue
                            let low = subSubJSON["3. low"].stringValue
                            let close = subSubJSON["4. close"].stringValue
                            let volume = subSubJSON["5. volume"].stringValue
                             
                            let value = ValueStock(start_timestamp: dateTime, open: open, high: high, low: low, close: close, volume: volume)
                            valuesStock.append(value)
                        }
                    }
                }
                dump (valuesStock)
                let sortedValues = valuesStock.sorted(by: { $0.start_timestamp > $1.start_timestamp })
                dump (sortedValues)
                valuesStock.removeAll()
                for (index, valueStock) in sortedValues.enumerated() {
                    if index <= 59 {
                        valuesStock.append(valueStock)
                    }
                }
                
                print (valuesStock)
                valuesStock.reverse()
                completion(.success(valuesStock))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    
    
    
    //MARK: API call for search of INDIVIDUAL stock with current price
    func getPriceSingleStock(tickerSingle: String, timeRange: String, completion: @escaping (Result<Tickers, Error>) -> Void) {
        
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
        ]
        
        let url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + tickerSingle + timeRange
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
                    completion(.failure(APIError.invalidJSON))
                }
                
                if let tickerFound = json![tickerSingle] {
                    let tickerDictionary = tickerFound as? [String: Any]
                    let foundClose = tickerDictionary!["chartPreviousClose"]
                    
                    guard let previousClose = foundClose as? Double else {
                        completion(.failure(APIError.invalidURL))
                        return
                    }
                    
                    guard let closePriceArray = tickerDictionary!["close"] as? [Any] else {
                        completion(.failure(APIError.invalidTicker))
                        return
                    }
                    guard let closePrice = closePriceArray.last as? Double else {
                        completion(.failure(APIError.invalidTicker))
                        return
                    }
                    
                    let tickerValues = Tickers(ticker: tickerSingle, marketPrice: closePrice, previousPrice: previousClose)

                    completion(.success(tickerValues))
                    
                } else {
                    print (APIError.tickerNotFound)
                    completion(.failure(APIError.invalidURL))
                }
            }
        })
        dataTask.resume()
    }
    
    //MARK: API call for GROUP of stocks with current price
    func getPriceMultipleStocks(tickersGroup: String, timeRange: String, completion: @escaping (Result<[Tickers], Error>) -> Void) {
        
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
                
                var tickersWithoutSorting : [Tickers] = []
                for tickerJSON in json! {
                    print (tickerJSON.value) //json
                    print (tickerJSON.key) //ticker
                    
                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray!.last as! Double
                    tickersWithoutSorting.append(Tickers(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose))
                }
                
                let tickersSorted = tickersWithoutSorting.sorted{ $0.ticker < $1.ticker }
                completion(.success(tickersSorted))
            }
        })
        dataTask.resume()
    }
    
    //MARK: API call for general markets
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
    
    //MARK: API call for news of specific ticker (stock)
    func loadTickerNews(ticker: String, completion: @escaping ([TickerNews]?) -> Void) {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "yahoo-finance15.p.rapidapi.com"
        ]

        let urlString = "https://yahoo-finance15.p.rapidapi.com/api/yahoo/ne/news/\(ticker)"
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
                
                let news = json!["item"] as! [Any]
                
                var tickerNewsArray = [TickerNews]()
                for (index, new) in news.enumerated() {
                
                    if index == 10 {
                        break
                    }
                    
                    let foundNew = new as? [String: Any]
                    let headline = foundNew!["title"] as! String
                    let date = self.newLocalTime(timeString: foundNew!["pubDate"] as! String)
                    let link = foundNew!["link"] as! String
                    
                    let tickerNews = TickerNews.init(headline: headline, pubDate: date, linkHeadline: link)
                    
                    print (tickerNews)
                    tickerNewsArray.append(tickerNews)
                }

                completion(tickerNewsArray)
            }
        })

        dataTask.resume()
    }
    //Change date format
    func newLocalTime(timeString: String) -> String {
        print (timeString)
        //Get date and format
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")
        
        //Convert format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current

        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        let newLocalTime = dateFormatter.string(from: dateObj!)

        return newLocalTime
    }
}
