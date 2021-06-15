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
        static let apiKey = "5e49ce50-9d28-431f-97a3-5661a78e0a4f"
        static let apiHeader = "X-CMC_PRO_API_KEY" //X-
        static let baseUrl = "https://pro-api.coinmarketcap.com/v1/"
        static let symbols = "btc,eth,ltc,doge,ada,dot,bch,xlm,bnb,xmr,xrp,usdt,link,usdc"
        static let endpoint = "cryptocurrency/quotes/latest"
    }
    
    //https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=btc,eth,ltc,doge&CMC_PRO_API_KEY=5e49ce50-9d28-431f-97a3-5661a78e0a4f
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
        //print (url)
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
                                
//                guard let cryptoData = response.data.values.first else {
//                    return
//                }
                 
                var valueCrypto: [CryptoData] = []

                for values in response.data.values {
                    valueCrypto.append(values)
                }
                
//                let sortedValues = valueCrypto.sorted { first, second -> Bool in
//                    return first.symbol < second.symbol
//                }
                print (valueCrypto)
                
                completion(.success(valueCrypto))
            } catch {
                completion(.failure(error))
                
            }
        }
        task.resume()
        
    }
        
}



