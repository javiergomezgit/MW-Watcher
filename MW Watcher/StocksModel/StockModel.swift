//
//  StockModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation
import UIKit

struct TickersFeatures {
    let ticker: String
    let nameTicker: String
    let imageTicker: UIImage
}

struct Stock {
    let ticker: String
    let nameTicker: String
}

struct TickersCurrentValues {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
    let changePercent: Double
}

struct GeneralMarkets {
    let indexTicker: String
    let indexName: String
    let indexPrice: Double
    let changePercentage: Double
}
