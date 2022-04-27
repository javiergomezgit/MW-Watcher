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
    
    //MARK: API Call for chart for general markets
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
    
    
    
    //MARK: API call for news of specific ticker (stock)
//    func loadTickerNews(ticker: String, completion: @escaping ([TickerNews]?) -> Void) {
//        let headers = [
//            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
//            "x-rapidapi-host": "yahoo-finance15.p.rapidapi.com"
//        ]
//
//        let urlString = "https://yahoo-finance15.p.rapidapi.com/api/yahoo/ne/news/\(ticker)"
//        let request = NSMutableURLRequest(url: NSURL(string: urlString)! as URL,
//                                                cachePolicy: .useProtocolCachePolicy,
//                                            timeoutInterval: 10.0)
//        request.httpMethod = "GET"
//        request.allHTTPHeaderFields = headers
//
//        let session = URLSession.shared
//        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
//            if (error != nil) {
//                completion(nil)
//            } else {
//
//                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
//
//                let news = json!["item"] as! [Any]
//
//                var tickerNewsArray = [TickerNews]()
//                for (index, new) in news.enumerated() {
//
//                    if index == 10 {
//                        break
//                    }
//
//                    let foundNew = new as? [String: Any]
//                    let headline = foundNew!["title"] as! String
//                    let date = Support.sharedSupport.newLocalTime(timeString: foundNew!["pubDate"] as! String)
//                    let link = foundNew!["link"] as! String
//
//                    let tickerNews = TickerNews.init(headline: headline, pubDate: date, linkHeadline: link)
//
//                    print (tickerNews)
//                    tickerNewsArray.append(tickerNews)
//                }
//
//                completion(tickerNewsArray)
//            }
//        })
//
//        dataTask.resume()
//    }
    
    //MARK: API call for live news
    func loadAllNews(completion: @escaping([NewsItem]?) -> Void){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url:
                                            NSURL(string: "https://bing-news-search1.p.rapidapi.com/news?safeSearch=Off&category=Business")! as URL,
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
                dump (json!)
                let jsonNews = json!["value"] as! [Any]
                     
                var newsItems = [NewsItem]()
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let notFormatedDate = dictionaryNew["datePublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                    let headline = dictionaryNew["name"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]

                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let newsItem = NewsItem.init(headline: headline, link: link, pubDate: pubDate, ticker: "", author: author, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
    
    
    //MARK: API call for news on specific stock
    func loadStockNews(ticker: String, completion: @escaping([TickerNews]?) -> Void){
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        //let request = NSMutableURLRequest(url: NSURL(string: "https://bing-news-search1.p.rapidapi.com/news/search?q=AAPL&freshness=Day&textFormat=Raw&safeSearch=Off")! as URL,

        let urlString = "https://bing-news-search1.p.rapidapi.com/news/search?q=\(ticker)&freshness=Day&textFormat=Raw&safeSearch=Off"
        
        let request = NSMutableURLRequest(url:
                                            NSURL(string: urlString)! as URL,
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
                dump (json!)
                let jsonNews = json!["value"] as! [Any]
                     
                var newsItems = [TickerNews]()
                for jsonNew in jsonNews {
                    
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let notFormatedDate = dictionaryNew["datePublished"] as! String
                    let pubDate = Support.sharedSupport.newLocalTimeNews(timeString: notFormatedDate)
                    let headline = dictionaryNew["name"] as! String
                    let link = dictionaryNew["url"] as! String
                    
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]

                    var downloadedImage = UIImage()
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        let imageLink = imageJSON?["contentUrl"] as! String
                        downloadedImage = Support.sharedSupport.downloadImageFeed(URLImage: imageLink)
                    } else {
                        downloadedImage = UIImage(named: "mw-logo")!
                    }
                    
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let newsItem = TickerNews.init(headline: headline, pubDate: pubDate, linkHeadline: link, author: author, image: downloadedImage)
                    newsItems.append(newsItem)
                }
                completion(newsItems)
            }
        })
        dataTask.resume()
    }
    
}
