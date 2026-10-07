//
//  WatchlistPriceStore.swift
//  Bullish Square
//
//  Created by Javier Gomez on 10/06/26.
//

import Foundation

///The watchlist's last prices and sparklines, per ticker, kept across launches.
///
///Prices lived only in memory, so every launch showed a spinner until the server answered.
///With these the rows show their last prices at once and refresh in the background. The fetch
///times are kept too, so a relaunch within the watchlist's 60 s freshness asks for nothing.
///
///Keyed by ticker, never by row. Cleared by account deletion: the tickers say which stocks
///someone watched. Main thread only.
final class WatchlistPriceStore {

    static let shared = WatchlistPriceStore()

    struct Snapshot {
        var values: [String: TickersCurrentValues]
        var fetchedAt: [String: Date]
    }

    private struct StoredPrice: Codable {
        let values: TickersCurrentValues?
        let fetchedAt: Date
    }

    private let fileURL: URL?
    private let diskQueue = DispatchQueue(label: "com.bullishsquare.watchlistprices", qos: .utility)

    private init() {
        //Caches: the system may clear it, which only costs one spinner.
        fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("watchlist-prices-v1.json")
    }

    func load() -> Snapshot {
        guard let fileURL, let saved = try? Data(contentsOf: fileURL) else {
            return Snapshot(values: [:], fetchedAt: [:])
        }
        do {
            let stored = try JSONDecoder().decode([String: StoredPrice].self, from: saved)
            return Snapshot(values: stored.compactMapValues(\.values),
                            fetchedAt: stored.mapValues(\.fetchedAt))
        } catch let error as NSError {
            print("Saved watchlist prices could not be read, starting empty: \(error.localizedDescription)")
            return Snapshot(values: [:], fetchedAt: [:])
        }
    }

    ///A ticker can have a fetch time without a price - the API left it out - and that is kept,
    ///so it is not asked for again on every launch.
    func save(values: [String: TickersCurrentValues], fetchedAt: [String: Date]) {
        guard let fileURL else { return }
        var stored: [String: StoredPrice] = [:]
        for (ticker, date) in fetchedAt {
            stored[ticker] = StoredPrice(values: values[ticker], fetchedAt: date)
        }
        do {
            let encoded = try JSONEncoder().encode(stored)
            diskQueue.async {
                do {
                    try encoded.write(to: fileURL, options: .atomic)
                } catch let error as NSError {
                    print("Watchlist prices could not be saved to disk: \(error.localizedDescription)")
                }
            }
        } catch let error as NSError {
            print("Watchlist prices could not be encoded for saving: \(error.localizedDescription)")
        }
    }

    func clear() {
        guard let fileURL else { return }
        diskQueue.async {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch let error as NSError {
                print("Saved watchlist prices could not be removed: \(error.localizedDescription)")
            }
        }
    }
}
