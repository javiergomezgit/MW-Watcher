//
//  CryptoAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import Foundation

final class CryptosAPI {
    static let shared = CryptosAPI()
    
    private struct Constant {
        //Constants for all cryptos API
        static let apiKey = "5e49ce50-9d28-431f-97a3-5661a78e0a4f"
        static let apiHeader = "X-CMC_PRO_API_KEY"
        static let baseUrl = "https://pro-api.coinmarketcap.com/v1/"
        static let symbols = "btc,eth,ltc,doge,ada,dot,bch,xlm,bnb,xmr,xrp,usdt,link,usdc"
        static let endpoint = "cryptocurrency/quotes/latest"
        
        //Constants for individual crypto API
        static let apiKeyIndividual = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
        static let apiHeaderIndividual = "investing-cryptocurrency-markets.p.rapidapi.com"
        static let baseURLIndividual = "https://investing-cryptocurrency-markets.p.rapidapi.com/coins/get-fullsize-chart?pair_ID="
        static var pair_ID = "945629"
        static var interval = "300"
    }
    private init() {}

    
    enum APIError: Error {
        case invalidURL
    }
    
    public func getAllCryptosData(completion: @escaping (Result<[CryptoData], Error>) -> Void) {
        guard let url = URL(string: Constant.baseUrl + Constant.endpoint + "?symbol=" + Constant.symbols) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.setValue(Constant.apiKey, forHTTPHeaderField: Constant.apiHeader)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                return
            }
            
            do {
                let response = try JSONDecoder().decode(CryptoAPIResponse.self, from: data)
                var valueCrypto: [CryptoData] = []
                for values in response.data.values {
                    valueCrypto.append(values)
                }
                completion(.success(valueCrypto))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    public func getSelectedCrypto(completion: @escaping (Result<[QuoteInvidual], Error>) -> Void) {
        let headers = [
            "X-RapidAPI-Host": Constant.apiHeaderIndividual,
            "X-RapidAPI-Key": Constant.apiKeyIndividual
        ]

        let request = NSMutableURLRequest(url: NSURL(string: Constant.baseURLIndividual + Constant.pair_ID + "&time_utc_offset=28800&lang_ID=1&pair_interval=" + Constant.interval)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        
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
                let response = try JSONDecoder().decode(CryptoIndividualAPIResponse.self, from: data)
        
                var valueCryptoIndividual: [QuoteInvidual] = []

                if let values = response.quotes_data.values.first  {
                    print (values)
                    for (index, value) in values.enumerated() {
                        if index < 60 {
                            valueCryptoIndividual.append(value)
                        } else {
                            break
                        }
                    }
                    let candleValues = valueCryptoIndividual.sorted(by: { $0.start_timestamp < $1.start_timestamp })

                    completion(.success(candleValues))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
