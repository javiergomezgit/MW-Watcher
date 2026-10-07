//
//  MarketsCache.swift
//  Bullish Square
//

import Foundation

///Everything the Markets tab shows, and the one place it is fetched from.
///
///Saved to disk so the tab opens with the last data on every launch instead of a spinner,
///and so a relaunch within five minutes spends nothing from the mboum plan (500 requests a
///month) that the three index lines come from.
///
///The five requests run at the same time. They used to run one after another, twice over:
///here at launch and again in the tab, each about 1 s, and the launch chain stored nothing
///at all if any single request failed.
///
///Main thread only.
final class MarketsCache {
    static let shared = MarketsCache()

    ///Posted on the main thread when a refresh has finished, whether or not every request
    ///succeeded. `userInfo["failed"]` is true when any of them failed.
    static let didUpdate = Notification.Name("MarketsCache.didUpdate")

    struct CachedData: Codable {
        let chartDJI: [MarketsCandles]
        let chartSP500: [MarketsCandles]
        let chartIXIC: [MarketsCandles]
        let marketQuotes: [GeneralMarkets]
        let cryptoData: [CryptoData]
        let timestamp: Int
    }

    private let freshness: TimeInterval = 300

    private var data: CachedData?
    private var fetchedAt: Date?
    private(set) var isRefreshing = false

    private let fileURL: URL?
    private let diskQueue = DispatchQueue(label: "com.bullishsquare.marketscache", qos: .utility)

    private init() {
        fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("markets-v1.json")
        loadFromDisk()
    }

    func get() -> CachedData? { data }

    func isStale(now: Date = Date()) -> Bool {
        guard let date = fetchedAt else { return true }
        return now.timeIntervalSince(date) > freshness
    }

    ///Fetches when the data is older than five minutes, or always when `force` (the refresh
    ///button). Does nothing while a refresh is already running; its didUpdate covers both.
    func refresh(force: Bool = false) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.refresh(force: force) }
            return
        }
        guard !isRefreshing, force || isStale() else { return }
        isRefreshing = true

        var dji: [MarketsCandles]?
        var sp500: [MarketsCandles]?
        var ixic: [MarketsCandles]?
        var quotes: (values: [GeneralMarkets], timestamp: Int)?
        var crypto: [CryptoData]?
        let group = DispatchGroup()

        //Each answer is written on the main thread, so the five never race on these.
        func index(_ symbol: String, into assign: @escaping ([MarketsCandles]) -> Void) {
            group.enter()
            ChartAPI.shared.getMajorMarketsValues(symbol: symbol) { result in
                DispatchQueue.main.async {
                    //An empty list is a real answer: getMajorMarketsValues keeps only candles
                    //since today's open, so before the open and at weekends it is empty, and
                    //counting that as a failure would never let the tab be fresh.
                    if case .success(let candles) = result { assign(candles) }
                    group.leave()
                }
            }
        }
        index("^DJI") { dji = $0 }
        index("^GSPC") { sp500 = $0 }
        index("^IXIC") { ixic = $0 }

        group.enter()
        StockAPI.shared.getPriceGeneralMarkets { values, timestamp in
            DispatchQueue.main.async {
                if let values { quotes = (values, timestamp) }
                group.leave()
            }
        }

        group.enter()
        CryptoAPI.shared.getAllCryptosData { result in
            DispatchQueue.main.async {
                if case .success(let coins) = result { crypto = coins }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isRefreshing = false
            let failed = dji == nil || sp500 == nil || ixic == nil || quotes == nil || crypto == nil
            let old = self.data

            //What failed keeps its last known value rather than blanking that part of the tab.
            if dji != nil || sp500 != nil || ixic != nil || quotes != nil || crypto != nil || old != nil {
                self.data = CachedData(chartDJI: dji ?? old?.chartDJI ?? [],
                                       chartSP500: sp500 ?? old?.chartSP500 ?? [],
                                       chartIXIC: ixic ?? old?.chartIXIC ?? [],
                                       marketQuotes: quotes?.values ?? old?.marketQuotes ?? [],
                                       cryptoData: crypto ?? old?.cryptoData ?? [],
                                       timestamp: quotes?.timestamp ?? old?.timestamp ?? 0)
                //Only a complete refresh counts as fresh, so a partial one is retried the
                //next time the tab or the app comes back.
                if !failed {
                    self.fetchedAt = Date()
                }
                self.saveToDisk()
            }
            NotificationCenter.default.post(name: Self.didUpdate, object: self, userInfo: ["failed": failed])
        }
    }

    // MARK: - Disk

    private struct Stored: Codable {
        let fetchedAt: Date?
        let data: CachedData
    }

    private func loadFromDisk() {
        guard let fileURL, let saved = try? Data(contentsOf: fileURL) else { return }
        do {
            let stored = try JSONDecoder().decode(Stored.self, from: saved)
            data = stored.data
            fetchedAt = stored.fetchedAt
        } catch let error as NSError {
            print("Saved markets data could not be read, starting empty: \(error.localizedDescription)")
        }
    }

    private func saveToDisk() {
        guard let fileURL, let data else { return }
        do {
            let encoded = try JSONEncoder().encode(Stored(fetchedAt: fetchedAt, data: data))
            diskQueue.async {
                do {
                    try encoded.write(to: fileURL, options: .atomic)
                } catch let error as NSError {
                    print("Markets data could not be saved to disk: \(error.localizedDescription)")
                }
            }
        } catch let error as NSError {
            print("Markets data could not be encoded for saving: \(error.localizedDescription)")
        }
    }
}
