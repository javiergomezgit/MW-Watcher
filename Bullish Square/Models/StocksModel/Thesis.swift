//
//  Thesis.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import Foundation

///Why someone watches a stock (Calm Investing §4.7). The six reasons a long-term investor gives,
///in the order the sheet shows them.
enum ThesisReason: String, CaseIterable {
    case longTermGrowth
    case strongBusiness
    case income
    case undervalued
    case speculative
    case researching

    var title: String {
        switch self {
        case .longTermGrowth: return "Long-term growth"
        case .strongBusiness: return "Strong business"
        case .income: return "Dividends / income"
        case .undervalued: return "Undervalued"
        case .speculative: return "Speculative"
        case .researching: return "Just researching"
        }
    }

    var symbolName: String {
        switch self {
        case .longTermGrowth: return "chart.line.uptrend.xyaxis"
        case .strongBusiness: return "building.2"
        case .income: return "dollarsign.circle"
        case .undervalued: return "tag"
        case .speculative: return "sparkles"
        case .researching: return "magnifyingglass"
        }
    }
}

///A person's reason for watching one stock on one watchlist, and what would make them look
///again (BS-318). The same stock on two lists has two theses, as the spec keys them.
///
///Price conditions are only stored here; BS-319 checks them each day. A condition left off is
///nil, so "25% below" is never confused with "not watched".
struct Thesis: Equatable {
    ///Uppercased, as the watchlist row keys it.
    let ticker: String
    let watchlistID: String
    var reason: ThesisReason
    ///The person's own words, up to `Thesis.noteLimit` characters. Empty when none.
    var note: String
    ///The close the person started from: the last settled close when the thesis was written.
    ///"yyyy-MM-dd", as health dates are.
    var startDate: String
    ///nil when no close could be had at the time; the card then shows the server's close for
    ///`startDate` instead.
    var startPrice: Double?
    var reconsiderOnTrendBreak: Bool
    ///A fraction: 0.25 is "25% below my starting price".
    var reconsiderBelowStart: Double?
    ///A fraction of the highest close since the start.
    var reconsiderBelowHigh: Double?
    ///The stock left the list (spec decision 6). Kept so adding it back restores it; Settings
    ///can delete every archived one.
    var archived: Bool
    ///Written by the server when a condition is met (BS-319); cleared by an answer, or
    ///snoozed by "remind me in a week".
    var pending: CheckIn? = nil
    ///Every answer, oldest first.
    var history: [CheckInRecord] = []
    ///Optional: a goal and when to start selling gradually (BS-320).
    var exitPlan: ExitPlan? = nil

    ///The check-in to ask about now: one that is snoozed waits for its reminder.
    var waitingCheckIn: CheckIn? {
        guard let pending, !pending.snoozed else { return nil }
        return pending
    }

    static let noteLimit = 280
    ///The starting point for both price conditions when someone turns one on.
    static let defaultDrop = 0.25

    ///A new thesis with the conditions a long-term investor would start with: a trend break.
    static func new(ticker: String, watchlistID: String, reason: ThesisReason,
                    startDate: String, startPrice: Double?) -> Thesis {
        Thesis(ticker: ticker.uppercased(), watchlistID: watchlistID, reason: reason, note: "",
               startDate: startDate, startPrice: startPrice, reconsiderOnTrendBreak: true,
               reconsiderBelowStart: nil, reconsiderBelowHigh: nil, archived: false)
    }
}

// MARK: - Exit plan (BS-320)

///What the money is for. "Other, no date" keeps a goal without reminders.
enum ExitGoal: String, CaseIterable {
    case retirement, house, education, other

    var title: String {
        switch self {
        case .retirement: return "Retirement"
        case .house: return "House"
        case .education: return "Education"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .retirement: return "sun.horizon"
        case .house: return "house"
        case .education: return "graduationcap"
        case .other: return "flag"
        }
    }
}

///A goal, its month, and how many months before it to start selling in monthly pieces. No
///amounts: the app doesn't know what the person holds. The server sends the reminders.
struct ExitPlan: Equatable {
    var goal: ExitGoal
    ///"2028-06"; nil for "Other, no date".
    var targetMonth: String?
    ///12 by default: the SPY research's 12 monthly pieces.
    var monthsBefore: Int

    static let defaultMonthsBefore = 12
    static let monthsBeforeChoices = [6, 12, 18, 24]

    enum Phase: Equatable {
        case noDate
        case before(monthsToStart: Int, monthsToGoal: Int)
        case selling(month: Int, of: Int)
        case past
    }

    ///The same months as the server's `exitPhase`, counted from this calendar month.
    func phase(on date: Date = Date()) -> Phase {
        guard let targetMonth, let target = Self.monthNumber(targetMonth) else { return .noDate }
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        let now = (parts.year ?? 0) * 12 + (parts.month ?? 1) - 1
        let start = target - monthsBefore
        if now >= target { return .past }
        if now >= start { return .selling(month: now - start + 1, of: monthsBefore) }
        return .before(monthsToStart: start - now, monthsToGoal: target - now)
    }

    ///"Jun 2028".
    var targetText: String? {
        targetMonth.flatMap(Self.monthNumber).map(Self.monthText)
    }

    ///"Jun 2027": when the selling window opens.
    var startText: String? {
        targetMonth.flatMap(Self.monthNumber).map { Self.monthText($0 - monthsBefore) }
    }

    ///"19 months to go · start selling gradually in Jun 2027", or where the window is.
    var countdown: String {
        switch phase() {
        case .noDate:
            return "No date, so no reminders"
        case .before(_, let toGoal):
            return "\(toGoal) months to go · start selling gradually in \(startText ?? "")"
        case .selling(let month, let of):
            return "Selling gradually: month \(month) of \(of)"
        case .past:
            return "The goal month has come"
        }
    }

    static func monthNumber(_ month: String) -> Int? {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]), (1...12).contains(number) else { return nil }
        return year * 12 + number - 1
    }

    ///"2028-06" for the month a date falls in.
    static func month(of date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 1)
    }

    ///The first day of a "2028-06" month, for the date picker.
    static func date(ofMonth month: String) -> Date? {
        guard let number = monthNumber(month) else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: number / 12, month: number % 12 + 1, day: 1))
    }

    private static func monthText(_ number: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: number / 12, month: number % 12 + 1, day: 15)) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Check-ins (BS-319)

///What the server found against the person's own conditions, after a close.
struct CheckIn: Equatable {

    enum Kind: String {
        case trendBreak, belowStart, belowHigh
    }

    struct Condition: Equatable {
        let kind: Kind
        ///A fraction for the price conditions; nil for a trend break.
        let threshold: Double?
        ///The trend break's confirming close, or the close that met a price condition.
        let date: String
        let close: Double
        ///The start close or the high since, for the price conditions.
        let reference: StockHealth.PricePoint?
    }

    ///The New York day the server wrote it.
    let createdOn: String
    ///It came back after "remind me in a week".
    let reminder: Bool
    let conditions: [Condition]
    let close: Double
    let asOf: String
    let snoozed: Bool
}

///The three answers the check-in offers.
enum CheckInAnswer: String, CaseIterable {
    case intact, changed, unsure

    var title: String {
        switch self {
        case .intact: return "Story intact"
        case .changed: return "Story changed"
        case .unsure: return "Not sure, remind me in a week"
        }
    }

    ///In the history, where "remind me" has already happened or will.
    var shortTitle: String {
        switch self {
        case .intact: return "Story intact"
        case .changed: return "Story changed"
        case .unsure: return "Not sure"
        }
    }
}

///One answer, with what it answered, as the thesis keeps it.
struct CheckInRecord: Equatable {
    ///"yyyy-MM-dd", New York.
    let date: String
    let answer: CheckInAnswer
    ///"11% below your start", worded when it was answered.
    let summary: String
}
