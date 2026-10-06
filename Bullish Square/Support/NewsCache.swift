//
//  NewsCache.swift
//  Bullish Square
//
//  Created by Javier Gomez on 4/14/26.
//

import UIKit

///The live news feed, per category, kept in memory and on disk.
///
///Saved to disk so the News tab opens with the last feed straight away on every launch,
///instead of a spinner over an empty screen while GNews answers. The saved copy also counts
///towards freshness, so a relaunch within five minutes does not spend GNews's 100-a-day quota.
///
///Main thread only. The prefetch hops here before storing.
final class NewsCache {
    static let shared = NewsCache()

    ///Posted on the main thread after a category is stored. The News tab listens for it
    ///instead of checking the cache once a second.
    static let didUpdate = Notification.Name("NewsCache.didUpdate")
    ///Posted on the main thread when a prefetch run has finished, whether or not every
    ///category came back, so pull to refresh always ends.
    static let prefetchDidFinish = Notification.Name("NewsCache.prefetchDidFinish")

    static let categories = ["business", "world", "general"]

    ///A category older than this is fetched again.
    let freshness: TimeInterval = 300

    private var data: [String: [NewsItem]] = [:]
    private var fetchedAt: [String: Date] = [:]

    private let fileURL: URL?
    private let diskQueue = DispatchQueue(label: "com.bullishsquare.newscache", qos: .utility)

    private init() {
        //Caches, not Documents: the system may clear it, and that only costs one fetch.
        fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("live-news-v1.json")
        loadFromDisk()
    }

    func isStale(_ category: String, now: Date = Date()) -> Bool {
        guard let date = fetchedAt[category] else { return true }
        return now.timeIntervalSince(date) > freshness
    }

    func store(category: String, items: [NewsItem], at now: Date = Date()) {
        data[category] = items
        fetchedAt[category] = now
        saveToDisk()
        NotificationCenter.default.post(name: Self.didUpdate, object: self)
    }

    func get(_ category: String) -> [NewsItem]? {
        data[category]
    }

    ///True when at least one category can be shown.
    var hasAnyNews: Bool {
        Self.categories.contains { !(data[$0]?.isEmpty ?? true) }
    }

    // MARK: - Disk

    ///Pictures are not saved: they are large, and each row reloads its own from the URL.
    private struct StoredCategory: Codable {
        let fetchedAt: Date
        let items: [StoredItem]
    }

    private struct StoredItem: Codable {
        let headline: String
        let link: String
        let pubDate: String
        let ticker: String
        let author: String
        let imageURL: String?
    }

    private func loadFromDisk() {
        guard let fileURL, let saved = try? Data(contentsOf: fileURL) else { return }
        do {
            let stored = try JSONDecoder().decode([String: StoredCategory].self, from: saved)
            let placeholder = UIImage(named: "mw-logo") ?? UIImage()
            for (category, entry) in stored {
                data[category] = entry.items.map {
                    NewsItem(headline: $0.headline, link: $0.link, pubDate: $0.pubDate, ticker: $0.ticker,
                             author: $0.author, image: placeholder, imageURL: $0.imageURL)
                }
                fetchedAt[category] = entry.fetchedAt
            }
        } catch let error as NSError {
            print("Saved news could not be read, starting empty: \(error.localizedDescription)")
        }
    }

    private func saveToDisk() {
        guard let fileURL else { return }
        var stored: [String: StoredCategory] = [:]
        for (category, items) in data {
            guard let date = fetchedAt[category] else { continue }
            stored[category] = StoredCategory(fetchedAt: date, items: items.map {
                StoredItem(headline: $0.headline, link: $0.link, pubDate: $0.pubDate,
                           ticker: $0.ticker, author: $0.author, imageURL: $0.imageURL)
            })
        }
        //Encoded here on the main thread, from a snapshot; only the write happens off it.
        do {
            let encoded = try JSONEncoder().encode(stored)
            diskQueue.async {
                do {
                    try encoded.write(to: fileURL, options: .atomic)
                } catch let error as NSError {
                    print("News could not be saved to disk: \(error.localizedDescription)")
                }
            }
        } catch let error as NSError {
            print("News could not be encoded for saving: \(error.localizedDescription)")
        }
    }
}
