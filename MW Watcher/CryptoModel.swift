//
//  CryptoModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/7/22.
//

import Foundation



//All crypto coins
struct CryptoAPIResponse: Codable {
    let data: [String: CryptoData]
}

struct CryptoData: Codable {
    let id: Int
    let name: String
    let symbol: String
    let quote: [String: Quote]
}

struct Quote: Codable {
    let price: Float
    let percent_change_24h: Float
    let percent_change_30d: Float
    let volume_24h: Float
}



//Individual Crypto coin
struct CryptoIndividualAPIResponse: Codable {
    let data: [String: [QuoteInvidual]]
}

struct QuoteInvidual: Codable {
    let startingAt: Int
    let open: String
    let high: String
    let low: String
    let close: String
    let avg: String
}
