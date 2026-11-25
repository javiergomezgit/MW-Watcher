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
