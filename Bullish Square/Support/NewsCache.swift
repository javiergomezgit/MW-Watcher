//
//  NewsCache.swift
//  Bullish Square
//
//  Created by Javier Gomez on 4/14/26.
//

import UIKit

///The live news feed, per topic chip, kept in memory and on disk, and which chip is picked.
///
///Saved to disk so the News tab opens with the last feed straight away on every launch,
///instead of a spinner over an empty screen while the server answers. The saved copy also
///counts towards freshness, so a relaunch within five minutes asks for nothing.
///
///Main thread only. The prefetch hops here before storing.
final class NewsCache {
    static let shared = NewsCache()

    ///Posted on the main thread after a category is stored. The News tab listens for it
    ///instead of checking the cache once a second.
    static let didUpdate = Notification.Name("NewsCache.didUpdate")
    ///Posted on the main thread when a topic's fetch has finished, whether or not it came
    ///back, so pull to refresh and the spinner always end. The object is the topic's id, or
    ///nil when nothing could run.
    static let prefetchDidFinish = Notification.Name("NewsCache.prefetchDidFinish")

    // MARK: - Topics

    struct Topic: Equatable {
        ///The server's /v1/market-news topic.
        let id: String
        ///The chip's title.
        let title: String
        ///Whether the server keeps this topic for news search. World is not kept. (BS-239)
        var searchable = true
    }

    ///The News tab's chips, in order. The first two are CNBC; World is GNews's world, general
    ///and business headlines merged on the server. (BS-231)
    ///
    ///Trending and Movers were dropped after 2.2.0: CNBC's most-read list repeated most of
    ///Markets (14 of 20 stories one day), and Movers was only the "biggest moves" lists. The
    ///server still serves both for 2.2.0's chips. A phone left on either opens on Markets. (BS-237)
    static let topics = [
        Topic(id: "markets", title: "Markets"),
        Topic(id: "economy", title: "Economy"),
        Topic(id: "world", title: "World", searchable: false)
    ]

    private static let selectedTopicKey = "newsSelectedTopic"

    ///The chip picked, kept across launches. Anything no longer offered falls back to Markets.
    var selectedTopic: String {
        get {
            let stored = UserDefaults.standard.string(forKey: Self.selectedTopicKey)
            return Self.topics.first { $0.id == stored }?.id ?? Self.topics[0].id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.selectedTopicKey)
        }
    }

    ///A topic older than this is fetched again. The server shares each topic for an hour, so
    ///asking more often costs no provider quota.
    let freshness: TimeInterval = 300

    private var data: [String: [NewsItem]] = [:]
    private var fetchedAt: [String: Date] = [:]

    private let fileURL: URL?
    private let briefFileURL: URL?
    private let diskQueue = DispatchQueue(label: "com.bullishsquare.newscache", qos: .utility)

    private init() {
        //Caches, not Documents: the system may clear it, and that only costs one fetch.
        //v2 since the switch from GNews, so the old feed is not shown after updating.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        fileURL = caches?.appendingPathComponent("live-news-v2.json")
        briefFileURL = caches?.appendingPathComponent("market-brief-v1.json")
        loadFromDisk()
        loadBriefFromDisk()
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

    func hasNews(for topic: String) -> Bool {
        !(data[topic]?.isEmpty ?? true)
    }

    // MARK: - Market brief

    ///A saved brief the server gave longer ago than this is not shown: it would describe a
    ///day that has passed.
    private static let briefMaxAge: TimeInterval = 24 * 3600

    private var brief: MarketBrief?
    private var briefStoredAt: Date?

    ///The last "Why markets moved", so Markets opens with the card already there. It used to
    ///appear only after the server answered, seconds in, on every launch. (BS-249)
    func marketBrief(now: Date = Date()) -> MarketBrief? {
        guard let briefStoredAt, now.timeIntervalSince(briefStoredAt) < Self.briefMaxAge else { return nil }
        return brief
    }

    func store(brief: MarketBrief, at now: Date = Date()) {
        self.brief = brief
        briefStoredAt = now
        guard let briefFileURL else { return }
        do {
            let encoded = try JSONEncoder().encode(StoredBrief(storedAt: now, brief: brief))
            diskQueue.async {
                do {
                    try encoded.write(to: briefFileURL, options: .atomic)
                } catch let error as NSError {
                    print("Market brief could not be saved to disk: \(error.localizedDescription)")
                }
            }
        } catch let error as NSError {
            print("Market brief could not be encoded for saving: \(error.localizedDescription)")
        }
    }

    // MARK: - Disk

    private struct StoredBrief: Codable {
        let storedAt: Date
        let brief: MarketBrief
    }

    private func loadBriefFromDisk() {
        guard let briefFileURL, let saved = try? Data(contentsOf: briefFileURL) else { return }
        do {
            let stored = try JSONDecoder().decode(StoredBrief.self, from: saved)
            brief = stored.brief
            briefStoredAt = stored.storedAt
        } catch let error as NSError {
            print("Saved market brief could not be read, starting without one: \(error.localizedDescription)")
        }
    }

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
            //A topic no longer offered, such as BS-230's "finance", is dropped rather than
            //being saved again on every write.
            for (category, entry) in stored where Self.topics.contains(where: { $0.id == category }) {
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
