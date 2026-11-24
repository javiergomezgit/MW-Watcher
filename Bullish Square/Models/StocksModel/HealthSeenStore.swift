//
//  HealthSeenStore.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import Foundation

///What each stock's health looked like the last time the user saw the watchlist, so the next
///visit can say "No change detected" or name what changed (BS-311). Health only moves at the
///close, so a visit compares states, not clock times.
///
///Scoped to the owner and the watchlist like every watchlist row, and kept on this device only:
///it's a reading position, not data to sync. Account deletion clears it by prefix.
final class HealthSeenStore {

    static let shared = HealthSeenStore()

    ///Every key starts with this, so account deletion can clear them all.
    static let keyPrefix = "healthSeen.v1."

    ///One stock's state when last reviewed.
    struct Record: Codable, Equatable {
        ///"uptrend|healthy", or "new" for a listing with too little history.
        var state: String
        ///The state before the last change, kept to word it ("trend break").
        var previousState: String?
        ///The review that found the last change. Only a change found by the latest review is new.
        var changedAt: Date?
    }

    private struct Saved: Codable {
        var records: [String: Record]
        var lastReviewAt: Date?
    }

    ///The changes the latest review found, by ticker, and whether there was anything to compare.
    struct Review: Equatable {
        var changes: [String: String]
        ///True when none of these stocks had been seen before: the first visit sets the baseline.
        var isFirst: Bool
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var key: String {
        "\(Self.keyPrefix)\(WatchlistSyncService.currentOwnerUID).\(WatchlistStore.shared.activeWatchlistID)"
    }

    // MARK: - State

    ///The state a health answer is compared by, or nil when there's nothing to compare (still
    ///loading, failed, unknown symbol): those stocks keep their old record untouched.
    static func state(for answer: StockHealthAnswer?) -> String? {
        switch answer {
        case .health(let health): return "\(health.trend.state.rawValue)|\(health.label.rawValue)"
        case .insufficientHistory: return "new"
        case .noData, .unavailable, nil: return nil
        }
    }

    ///"trend break", "back in uptrend", "now Attention". nil when nothing worth saying changed,
    ///such as a new listing getting its first 200 closes.
    static func changeText(from old: String, to new: String) -> String? {
        let oldParts = old.split(separator: "|").map(String.init)
        let newParts = new.split(separator: "|").map(String.init)
        guard oldParts.count == 2, newParts.count == 2 else { return nil }
        if oldParts[0] != newParts[0] {
            return newParts[0] == TrendState.downtrend.rawValue ? "trend break" : "back in uptrend"
        }
        guard oldParts[1] != newParts[1], let label = HealthLabel(rawValue: newParts[1]) else { return nil }
        return "now " + StockHealthFormat.title(for: label)
    }

    // MARK: - Review

    ///Appearances closer together than this are one visit: going into a stock's chart and back
    ///keeps the change on screen instead of counting as the next visit.
    static let visitGap: TimeInterval = 30 * 60

    ///Compares `states` (by uppercased ticker) with the last ones seen on the active watchlist,
    ///records them, and returns what changed. Called on every appearance; a change is reported
    ///for the visit that finds it and not again.
    func review(_ states: [String: String], at now: Date = Date()) -> Review {
        var saved = load()
        var changes: [String: String] = [:]
        let isFirst = states.keys.allSatisfy { saved.records[$0] == nil }

        //Same visit and nothing new: the changes already shown stay, and the visit doesn't move.
        let nothingNew = states.allSatisfy { saved.records[$0.key]?.state == $0.value }
        if nothingNew, let last = saved.lastReviewAt, now.timeIntervalSince(last) < Self.visitGap {
            for (ticker, record) in saved.records where record.changedAt == last {
                if let previous = record.previousState, let text = Self.changeText(from: previous, to: record.state) {
                    changes[ticker] = text
                }
            }
            return Review(changes: changes, isFirst: isFirst)
        }
        for (ticker, state) in states {
            guard let old = saved.records[ticker] else {
                saved.records[ticker] = Record(state: state)
                continue
            }
            guard old.state != state else { continue }
            if let text = Self.changeText(from: old.state, to: state) {
                changes[ticker] = text
                saved.records[ticker] = Record(state: state, previousState: old.state, changedAt: now)
            } else {
                saved.records[ticker] = Record(state: state)
            }
        }
        saved.lastReviewAt = now
        save(saved)
        return Review(changes: changes, isFirst: isFirst)
    }

    ///For the chart screen: the change the latest watchlist review found for this stock, or
    ///"" when it was reviewed and nothing changed. nil when the active watchlist hasn't seen it.
    func latestChange(for ticker: String) -> String? {
        let saved = load()
        guard let record = saved.records[ticker.uppercased()] else { return nil }
        guard let changedAt = record.changedAt, changedAt == saved.lastReviewAt,
              let previous = record.previousState else { return "" }
        return Self.changeText(from: previous, to: record.state) ?? ""
    }

    ///Every owner's and watchlist's records, for account deletion.
    func clearAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Storage

    private func load() -> Saved {
        guard let data = defaults.data(forKey: key) else { return Saved(records: [:], lastReviewAt: nil) }
        do {
            return try JSONDecoder().decode(Saved.self, from: data)
        } catch let error as NSError {
            print("Health seen on this watchlist could not be read, starting again: \(error.localizedDescription)")
            return Saved(records: [:], lastReviewAt: nil)
        }
    }

    private func save(_ saved: Saved) {
        do {
            defaults.set(try JSONEncoder().encode(saved), forKey: key)
        } catch let error as NSError {
            print("Health seen on this watchlist could not be saved: \(error.localizedDescription)")
        }
    }
}
