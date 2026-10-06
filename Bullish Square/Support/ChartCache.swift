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

    ///Index charts and stock charts come from different providers, so they never share a key
    ///even for the same symbol.
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
    ///Stock 15 min and 1 hr: the stock endpoint returns completed candles only (measured
    ///2026-10-05: at 12:44 New York the newest 15 min candle was 12:15-12:30), so nothing can
    ///change until the candle after the newest one has closed. With 8:45-9:00 cached, 9:00-9:15
    ///completes at 9:15, and before then a request would return the same candles.
    ///
    ///At least a minute between requests either way: a provider can publish a completed
    ///candle a few minutes late, and with the market closed no new candle ever comes, so
    ///without it every visit after hours would ask again.
    ///
    ///Index charts come from mboum, whose newest point is live rather than a completed candle,
    ///so they keep the plain one-minute rule. Day and week: fifteen minutes; whether today's
    ///unfinished daily candle is included has not been measured.
    func isStale(_ entry: Entry, interval: String, isIndex: Bool, now: Date = Date()) -> Bool {
        let sinceFetch = now.timeIntervalSince(entry.fetchedAt)
        guard let candleLength = Self.intradayCandleLength(interval) else {
            return sinceFetch >= 15 * 60
        }
        guard sinceFetch >= 60 else { return false }
        guard !isIndex, let newestStart = entry.values.last?.start_timestamp else { return true }
        let nextCandleCompletes = newestStart + 2 * candleLength
        return now.timeIntervalSince1970 >= nextCandleCompletes
    }

    ///Seconds per candle for the intraday timeframes, nil for day and week.
    private static func intradayCandleLength(_ interval: String) -> TimeInterval? {
        if interval.hasPrefix("15m") { return 15 * 60 }
        if interval.hasPrefix("1h") { return 60 * 60 }
        return nil
    }
}
