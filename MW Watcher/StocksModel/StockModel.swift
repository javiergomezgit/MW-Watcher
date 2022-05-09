//
//  StockModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation
import UIKit


//struct TickerValues {
//    let ticker: String?
//    let nameCompany: String?
//    let marketPrice: Double?
//    let previousPrice: Double?
//    let volume: Double?
//    let imageCompany: UIImage?
//}
//
//
//
//
//struct TickersPriceGroup {
//    let ticker: String
//    let closePrice: Double
//    let previousClosePrice: Double
//    let changePercentagePrice: Double
//}

struct TickersFeatures {
    let ticker: String
    let nameTicker: String
    let imageTicker: UIImage
}

struct TickersCurrentValues {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
    let changePercent: Double
//    let volume: Double?
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
