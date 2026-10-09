//
//  ChartAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/3/25.
//


import Foundation
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
    
    //MARK: Chart candles, from the Bullish Square server
    ///Candles for a stock's chart. `intervalTime` is the chart's timeframe string, such as
    ///"15m&limit=35"; only the part before "&" is used (15m, 1h, 1d or 1wk).
    ///
    ///Stock and index charts used to call two providers from the phone with the RapidAPI key
    ///built into the app - yahoo-finance15 for stocks, mboum for indices, which ran out of
    ///quota and broke the index chart. Both now ask the server's /v1/history, which holds the
    ///key and shares each chart between every user. (BS-212)
    public func getStockValues(intervalTime: String, symbol: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        getHistory(symbol: symbol, intervalTime: intervalTime, completion: completion)
    }
    
    ///Candles for an index chart (^DJI, ^GSPC, ^IXIC) opened from Markets. The same server route
    ///as stocks; kept as its own entry point because ChartController and ChartCache keep the two
    ///apart.
    func getMarketValues(intervalTime: String, symbol: String, completion: @escaping(Result<[ValueStock], Error>) -> Void) {
        getHistory(symbol: symbol, intervalTime: intervalTime, completion: completion)
    }
    
    private struct HistoryResponse: Decodable {
        let candles: [Candle]
        
        struct Candle: Decodable {
            let time: Double
            let open: Double
            let high: Double
            let low: Double
            let close: Double
            let volume: Double
        }
    }
    
    ///The server sends the last 35 candles, oldest first, with the candle still forming last
    ///and bars missing a price already removed.
    private func getHistory(symbol: String, intervalTime: String, completion: @escaping (Result<[ValueStock], Error>) -> Void) {
        let interval = intervalTime.components(separatedBy: "&").first ?? intervalTime
        //"^" in index symbols must be escaped in a query.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: allowed) else {
            completion(.failure(APIError.invalidTicker))
            return
        }
        
        MarketDataServer.authorizedRequest(path: "/v1/history?symbol=\(encodedSymbol)&interval=\(interval)") { result in
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
                        let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
                        completion(.success(decoded.candles.map {
                            ValueStock(start_timestamp: $0.time, open: $0.open, high: $0.high,
                                       low: $0.low, close: $0.close, volume: $0.volume)
                        }))
                    } catch let error as NSError {
                        print("Chart for \(symbol) came back in an unexpected shape: \(error.localizedDescription)")
                        completion(.failure(APIError.invalidJSON))
                    }
                case 404:
                    //The server's "no_data": the provider has no chart for this symbol.
                    completion(.failure(APIError.tickerNotFound))
                default:
                    print("Chart server answered \(httpResponse.statusCode) for \(symbol): \(String(data: data, encoding: .utf8) ?? "")")
                    completion(.failure(APIError.invalidJSON))
                }
            }.resume()
        }
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
