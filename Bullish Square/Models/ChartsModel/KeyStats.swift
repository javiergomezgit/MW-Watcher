//
//  KeyStats.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import Foundation

///The chart screen's Key stats card (BS-327), worked out from the bars the chart already loads:
///the latest session's 1D bars and the 1Y daily bars. No request of its own.
///
///Highs and lows are the bars' highs and lows, so the 52-week range includes intraday moves,
///like a quote page, and matches the candles above it. Each value is nil until its bars arrive
///or when the provider sends nothing usable (an index has no volume), and shows as a dash.
struct KeyStats: Equatable {
    var open: Double?
    var high: Double?
    var low: Double?
    var volume: Double?
    var high52w: Double?
    var low52w: Double?
    ///Average daily volume over the last 63 sessions, about three months.
    var averageVolume3m: Double?
    ///From the first close in the 1Y bars to the last, as a percent.
    var change1y: Double?

    ///Sessions in "Avg vol (3M)".
    static let averageVolumeSessions = 63

    ///The latest session's open, high, low and volume, from its 15-minute bars. Volume is nil
    ///when every bar has none, which is how the providers send an index.
    mutating func setSession(_ bars: [ValueStock]) {
        guard let first = bars.first else { return }
        open = first.open
        high = bars.map(\.high).max()
        low = bars.map(\.low).min()
        let total = bars.reduce(0) { $0 + $1.volume }
        volume = total > 0 ? total : nil
    }

    ///The 52-week range, the three-month average volume and the 1-year change, from daily bars.
    mutating func setYear(_ bars: [ValueStock]) {
        guard let first = bars.first, let last = bars.last else { return }
        high52w = bars.map(\.high).max()
        low52w = bars.map(\.low).min()
        let recent = bars.suffix(Self.averageVolumeSessions).map(\.volume)
        let average = recent.reduce(0, +) / Double(max(recent.count, 1))
        averageVolume3m = average > 0 ? average : nil
        change1y = first.close > 0 ? (last.close - first.close) / first.close * 100 : nil
    }

    ///"41.2M", "1.05B", "850K": volumes are read at a glance, not to the share.
    static func compactVolume(_ value: Double) -> String {
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (size, suffix) in units where value >= size {
            let scaled = value / size
            return String(format: scaled >= 100 ? "%.0f%@" : (scaled >= 10 ? "%.1f%@" : "%.2f%@"), scaled, suffix)
        }
        return String(format: "%.0f", value)
    }
}
