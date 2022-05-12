//
//  ChartsModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/12/22.
//

import Foundation


struct ValueStock: Codable {
    let start_timestamp: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct MarketsCandles: Codable {
    let start_timestamp: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}
