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
    let imageTickerName: String
}

struct Stock {
    let ticker: String
    let nameTicker: String
    let exchange: String
    let stockType: String
}

struct TickersCurrentValues {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
    let changePercent: Double
    ///Every close of the day's session, oldest first, for the watchlist sparkline. Defaulted
    ///so the other places that build this type need no change and simply leave it empty.
    var intradayCloses: [Double] = []
}

///Codable so the Markets tab can be saved to disk (MarketsCache).
struct GeneralMarkets: Codable {
    let indexTicker: String
    let indexName: String
    let indexPrice: Double
    let changePercentage: Double
}
