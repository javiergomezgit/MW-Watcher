//
//  StockModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation

struct Tickers {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
}

struct ValueStock: Codable {
    let start_timestamp: String
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String
}

struct GeneralMarkets {
    let indexTicker: String
    let indexName: String
    let indexPrice: Double
    let changePercentage: Double
    let exchange: String
}


