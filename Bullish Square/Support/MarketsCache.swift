//
//  MarketsCache.swift
//  Bullish Square
//

import Foundation

class MarketsCache {
    static let shared = MarketsCache()
    private init() {}

    struct CachedData {
        let chartDJI: [MarketsCandles]
        let chartSP500: [MarketsCandles]
        let chartIXIC: [MarketsCandles]
        let marketQuotes: [GeneralMarkets]
        let cryptoData: [CryptoData]
        let timestamp: Int
    }

    private var data: CachedData?
    private var fetchedAt: Date?

    func store(_ data: CachedData) {
        self.data = data
        fetchedAt = Date()
    }

    func get() -> CachedData? { data }

    func isStale() -> Bool {
        guard let date = fetchedAt else { return true }
        return Date().timeIntervalSince(date) > 300
    }

    func clear() {
        data = nil
        fetchedAt = nil
    }
}
