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
        static let apiKey = "DF6FD5CE-AD03-4D28-AF2A-FD5E72009E7F"
        static let assetsEndpoint = "https://rest-sandbox.coinapi.io/v1/assets/"
    }
    
    private init() {}
    
    public var icons: [Icon] = []
    
    private var whenReadyBlock: ((Result<[Crypto], Error>) -> Void)?
    
    public func getAllCryptosData(
        completion: @escaping (Result<[Crypto], Error>) -> Void
    ) {
        guard !icons.isEmpty else {
            whenReadyBlock = completion
            return
        }
        
        guard let url = URL(string: Constant.assetsEndpoint + "?apikey=" + Constant.apiKey) else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                return
            }
            
            do {
                //DECODE response
                let cryptos = try JSONDecoder().decode([Crypto].self, from: data)
                
                completion(.success(cryptos.sorted { first, second -> Bool in
                    return first.price_usd ?? 0 > second.price_usd ?? 0
                }))
                
            } catch {
                completion(.failure(error))
            }
            
        }
        task.resume()
    }
    
    public func getAllIcons() {
        guard let url = URL(string:
                "https://rest-sandbox.coinapi.io/v1/assets/icons/55/?apikey=DF6FD5CE-AD03-4D28-AF2A-FD5E72009E7F")
        else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                return
            }
            
            do {
                //DECODE response
                self?.icons = try JSONDecoder().decode([Icon].self, from: data)
                if let completion = self?.whenReadyBlock {
                    self?.getAllCryptosData(completion: completion)
                }
                
            } catch {
                print (error)
            }
            
        }
        task.resume()
    }
}



