//
//  StockModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation
import UIKit

struct Tickers {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
    let nameCompany: String
    let volume: Double
}

struct SavedTickers {
    let ticker: String
    let nameCompany: String
    let imageCompany: UIImage
}

struct ValueStock: Codable {
    let start_timestamp: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct GeneralMarkets {
    let indexTicker: String
    let indexName: String
    let indexPrice: Double
    let changePercentage: Double
    let exchange: String
}


