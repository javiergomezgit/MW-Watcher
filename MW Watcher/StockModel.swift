//
//  StockModel.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation

struct ValueStock: Codable {
    let start_timestamp: String
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String
}
