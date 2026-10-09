//
//  ChartCache.swift
//  Bullish Square
//
//  Created by Javier Gomez on 10/06/26.
//

import Foundation

///Chart candles already downloaded, per symbol and timeframe, for the life of the app.
///
///Every chart open and every timeframe switch used to be a new request of about 1.5 s, so
///going 15 min -> 1 hr -> 15 min waited the full time again for candles just seen. Shared
///across screens, so a stock opened from the watchlist and again from search is drawn at once.
///
///In memory only, like MarketsCache: candles go stale within minutes, so a copy from the
///last launch would mostly be refetched anyway. Main thread only.
final class ChartCache {

    static let shared = ChartCache()

    struct Entry {
        let values: [ValueStock]
        let fetchedAt: Date
    }

    ///Enough for a long session of browsing; each entry is about 35 candles.
    private let capacity = 60
    private var entries: [String: Entry] = [:]

    private init() {}

    ///Index and stock charts are kept apart, as ChartController treats them as two kinds of
    ///chart; both now come from the same server route.
    private func key(symbol: String, interval: String, isIndex: Bool) -> String {
        "\(isIndex ? "index" : "stock")|\(symbol)|\(interval)"
    }

    func entry(symbol: String, interval: String, isIndex: Bool) -> Entry? {
        entries[key(symbol: symbol, interval: interval, isIndex: isIndex)]
    }

    func store(_ values: [ValueStock], symbol: String, interval: String, isIndex: Bool, at now: Date = Date()) {
        entries[key(symbol: symbol, interval: interval, isIndex: isIndex)] = Entry(values: values, fetchedAt: now)
        if entries.count > capacity,
           let oldest = entries.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key {
            entries.removeValue(forKey: oldest)
        }
    }

    ///Whether asking again could bring anything new.
    ///
    ///Charts come from the server's /v1/history, which includes the candle still forming, so
    ///an intraday chart can change every minute while the market is open: 15 min and 1 hr are
    ///refreshed after a minute, matching the server's own cache. Day and week candles barely
    ///move within a quarter of an hour.
    ///
    ///This used to wait for the next candle to close on stock charts, because the old stock
    ///provider sent completed candles only; with the forming candle that would leave it stale
    ///on screen for up to half an hour.
    func isStale(_ entry: Entry, interval: String, now: Date = Date()) -> Bool {
        let isIntraday = interval.hasPrefix("15m") || interval.hasPrefix("1h")
        return now.timeIntervalSince(entry.fetchedAt) >= (isIntraday ? 60 : 15 * 60)
    }
}
