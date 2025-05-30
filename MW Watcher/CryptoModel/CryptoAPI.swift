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
    // Takes a symbol and interval, returns up to 60 sorted QuoteIndividual entries
    public func getSelectedCrypto(interval: String, symbol: String, completion: @escaping (Result<[QuoteInvidual], Error>) -> Void) {
        // Construct URL with query parameters
        let urlComposed = NSMutableURLRequest(url: NSURL(string: KeysAndConstants.baseURLIndividual + symbol + KeysAndConstants.variables + interval)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
        guard let url = urlComposed.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Configure request with headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(KeysAndConstants.apiKeyIndividual, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(KeysAndConstants.apiHeaderIndividual, forHTTPHeaderField: "x-rapidapi-host")
        
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
        }
        task.resume()
    }
}
