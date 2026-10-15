//
//  CryptoAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/30/25.
//

//
//  CryptoAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import Foundation

final class CryptoAPI {
    static let shared = CryptoAPI()
    
    private init() {}
    
    enum APIError: Error {
        case invalidURL
        case invalidResponse
        case noData
    }
    
    // MARK: Fetches data for a predefined group of cryptocurrencies
    // Uses a hardcoded list of symbols and returns an array of CryptoData
    public func getAllCryptosData(completion: @escaping (Result<[CryptoData], Error>) -> Void) {
        // Construct URL with query parameters
        guard var urlComponents = URLComponents(string: KeysAndConstants.baseUrl + KeysAndConstants.endpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        urlComponents.queryItems = [URLQueryItem(name: "symbol", value: KeysAndConstants.symbols)]
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Configure request with API key header
        var request = URLRequest(url: url)
        request.setValue(KeysAndConstants.apiKey, forHTTPHeaderField: KeysAndConstants.apiHeader)
        request.httpMethod = "GET"
        
        // Perform API call
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            
            // Ensure data exists
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // Decode response
            do {
                let response = try JSONDecoder().decode(CryptoAPIResponse.self, from: data)
                let cryptoData = Array(response.data.values)
                completion(.success(cryptoData))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    
    // MARK: Fetches historical data for a specific cryptocurrency
    ///A coin's chart: `symbol` is its Investing.com pair ID (ChartController maps coins to
    ///pairs) and `interval` is 300, 900, 3600, 18000, week or month. Up to 60 candles, oldest
    ///first. Completes exactly once.
    ///
    ///Asks the Bullish Square server's /v1/crypto-chart, which shares each chart between every
    ///user and sends Investing.com's own shape trimmed to the newest 60, so the decoding below
    ///is unchanged. It used to call Investing.com from the phone with the RapidAPI key built
    ///into the app - the last live call that did. (BS-212)
    public func getSelectedCrypto(interval: String, symbol: String, completion: @escaping (Result<[QuoteInvidual], Error>) -> Void) {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        guard let pair = symbol.addingPercentEncoding(withAllowedCharacters: allowed),
              let timeframe = interval.addingPercentEncoding(withAllowedCharacters: allowed) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        MarketDataServer.authorizedRequest(path: "/v1/crypto-chart?pair=\(pair)&interval=\(timeframe)") { result in
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
                
                // Validate HTTP response
                guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Crypto chart server answered \(httpResponse.statusCode) for pair \(symbol), interval \(interval)")
                    }
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                
                // Ensure data exists
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
                
                // Decode response
                do {
                    let response = try JSONDecoder().decode(CryptoIndividualAPIResponse.self, from: data)
                    guard let values = response.quotes_data.values.first else {
                        completion(.success([]))
                        return
                    }
                    
                    // Limit to 60 entries and sort by timestamp
                    let candleValues = values.prefix(60).sorted { $0.start_timestamp < $1.start_timestamp }
                    completion(.success(Array(candleValues)))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    }
}
