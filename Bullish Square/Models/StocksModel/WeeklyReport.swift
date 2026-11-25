//
//  WeeklyReport.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import Foundation

///The week on someone's watchlists, as /v1/this-week answers it (BS-317): the same report and
///the same words as the Friday email's "This week on your watchlist" (BS-316). The server words
///every line, so the screen and the email can't drift apart.
struct WeeklyReport: Decodable {

    ///A stock whose trend or overall label changed this week.
    struct Change: Decodable {
        let symbol: String
        ///The close that confirmed it, "2026-11-17".
        let date: String
        ///Set when the trend flipped; the label then only follows it.
        let trend: TrendState?
        let label: HealthLabel
        ///Set when only the label changed.
        let previousLabel: HealthLabel?
        let pctFromHigh: Double
        ///"Trend break on 17 Nov".
        let headline: String
        ///"−32% from its high".
        let detail: String
    }

    ///Calm, mixed or stressed, with the line that explains it.
    struct Market: Decodable {
        let label: String
        ///"Mixed — S&P 500 in an uptrend, volatility 1.6× its normal, 3 of 5 in an uptrend".
        let line: String
    }

    ///The last settled close the report describes.
    let day: String
    ///Monday of the week.
    let weekStart: String
    ///Newest first.
    let changes: [Change]
    let unchanged: [String]
    ///Under 200 closes, or no closes at all.
    let noHealth: [String]
    let market: Market?
}
