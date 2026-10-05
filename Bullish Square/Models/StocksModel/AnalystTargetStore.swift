//
//  AnalystTargetStore.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/30/26.
//

import Foundation

///Remembers each stock's analyst consensus for a day, across launches.
///
///Targets change a few times a month at most, and every fetch spends from the market-data
///quota, so an in-memory cache would re-ask for every stock on every launch. A stock with no
///coverage - an ETF, a small cap, a coin - is remembered as "none" the same way, so SPY is not
///re-requested each time the watchlist appears.
///
///Market data rather than anything personal, so it is not scoped to the signed-in user and
///survives sign-out, like the logos.
final class AnalystTargetStore {

    static let shared = AnalystTargetStore()

    ///What was learned about one ticker, and when.
    struct Entry: Codable, Equatable {
        let fetchedAt: Date
        ///nil means the server said no analyst covers this stock.
        let target: AnalystTarget?
    }

    ///Matches the server's cache, so the app never asks for something the server would only
    ///answer from memory anyway.
    let freshness: TimeInterval = 24 * 60 * 60

    ///Versioned so a future change to `AnalystTarget` can start over instead of failing to decode.
    private let defaultsKey = "analystTargets.v1"
    private let defaults: UserDefaults
    private var entries: [String: Entry]

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey) {
            do {
                entries = try JSONDecoder().decode([String: Entry].self, from: data)
            } catch let error as NSError {
                print("Stored analyst targets could not be read, starting empty: \(error.localizedDescription)")
                entries = [:]
            }
        } else {
            entries = [:]
        }
    }

    ///Whatever is known, fresh or not. An old target is still worth showing while a new one
    ///loads; it is at most a day or two behind.
    func entry(for ticker: String) -> Entry? {
        entries[ticker]
    }

    func needsFetch(_ ticker: String, now: Date = Date()) -> Bool {
        guard let entry = entries[ticker] else { return true }
        return now.timeIntervalSince(entry.fetchedAt) >= freshness
    }

    ///Only for a real answer: a target, or the server's "no coverage". A failed request is not
    ///recorded, so the next appearance tries again.
    func record(_ target: AnalystTarget?, for ticker: String, at now: Date = Date()) {
        entries[ticker] = Entry(fetchedAt: now, target: target)
        save()
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(entries), forKey: defaultsKey)
        } catch let error as NSError {
            print("Analyst targets could not be saved: \(error.localizedDescription)")
        }
    }
}
