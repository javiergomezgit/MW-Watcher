//
//  StockHealth.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import Foundation

///Whether a stock is above or below its 200-day average, confirmed after two closes on the
///new side so one day's noise doesn't flip it. A state, never an instruction.
enum TrendState: String, Codable {
    case uptrend
    case downtrend
}

///The overall health label the server works out (rules in the API's `HEALTH_RULES`). It
///describes the price history; it is never a Buy/Hold/Sell call, and it is calculated on the
///server so the app, the email and future alerts can't disagree.
enum HealthLabel: String, Codable {
    case healthy
    case attention
    case weak
    case recovering
}

///RSI(14) in words: below 30 oversold, above 70 overbought, else neutral.
enum RsiWord: String, Codable {
    case oversold
    case neutral
    case overbought
}

///One stock's health facts from ten years of daily closes, as /v1/health answers them (BS-307).
///
///Percentages are fractions (-0.387 is -38.7%) and dates are New York trading days as
///"yyyy-MM-dd" strings; `StockHealthFormat` turns both into words. Every field the server always
///sends is non-optional, so a dropped field fails the decode loudly instead of showing a blank.
struct StockHealth: Codable, Equatable {
    let symbol: String
    ///The close these facts describe. Shown as "As of 13 Nov 2026 close".
    let asOf: String
    let close: Double
    let historyDays: Int
    let trend: Trend
    let sma50: Double
    let sma200: Double
    ///How far the close is above (+) or below (-) the 200-day average.
    let pctVs200: Double
    let high52w: PricePoint
    let low52w: PricePoint
    let allTimeHigh: PricePoint
    ///From the all-time high, so always zero or below.
    let pctFromHigh: Double
    ///The rise needed to get back to the all-time high: a 50% fall needs +100%.
    let recoveryNeeded: Double
    ///Annualised, from the last 252 closes; nil with too few.
    let volatility: Double?
    ///SPY's volatility on the same basis, so "25% a year" can be read against the market.
    let marketVolatility: Double?
    ///nil for a stock that has never fallen.
    let worstDrop: WorstDrop?
    let rsi14: Double?
    let rsiWord: RsiWord?
    ///Price-only, without dividends; nil with less than a year of closes.
    let return1y: Double?
    let label: HealthLabel

    struct Trend: Codable, Equatable {
        let state: TrendState
        ///The day the current trend was confirmed.
        let since: String
        ///True when the trend has held for all the history there is, so `since` is only where
        ///the data starts: "Uptrend for 10 years or more", not "since 2016".
        let sinceIsStartOfData: Bool
    }

    struct PricePoint: Codable, Equatable {
        let value: Double
        let date: String
    }

    ///The deepest fall from a peak in the history, and how long the climb back took.
    struct WorstDrop: Codable, Equatable {
        let depth: Double
        let peak: PricePoint
        let trough: PricePoint
        ///nil while it hasn't got back to the old peak.
        let recoveredOn: String?
        ///Trading days from the trough to the recovery.
        let daysToRecover: Int?
    }
}

///What the server knows about one symbol's health.
enum StockHealthAnswer: Equatable {
    case health(StockHealth)
    ///Fewer than 200 closes: a recent listing. Shown as "Not enough history yet".
    case insufficientHistory(days: Int)
    ///The provider doesn't know the symbol.
    case noData
    ///Its batch failed on the server with nothing cached. Worth asking again later.
    case unavailable

    ///The health, when there is one.
    var health: StockHealth? {
        if case .health(let health) = self { return health }
        return nil
    }

    // MARK: - Parsing

    enum ParseError: Error {
        case unknownError(String)
    }

    ///Only for telling an error body from a health body; the error words the server sends.
    private struct ErrorBody: Decodable {
        let symbol: String
        let error: String?
        let historyDays: Int?
    }

    private struct Batch: Decodable {
        let health: [Answer]
    }

    ///One element of either shape, decoded by first looking for "error".
    private struct Answer: Decodable {
        let symbol: String
        let answer: StockHealthAnswer

        init(from decoder: Decoder) throws {
            let head = try ErrorBody(from: decoder)
            symbol = head.symbol
            switch head.error {
            case nil:
                answer = .health(try StockHealth(from: decoder))
            case "insufficient_history":
                guard let days = head.historyDays else {
                    throw ParseError.unknownError("insufficient_history without historyDays")
                }
                answer = .insufficientHistory(days: days)
            case "no_data":
                answer = .noData
            case "unavailable":
                answer = .unavailable
            case let other?:
                throw ParseError.unknownError(other)
            }
        }
    }

    ///Parses /v1/health/:symbol, whose 200 is a health body and whose 404 is an error body.
    static func parseOne(_ data: Data) throws -> StockHealthAnswer {
        try JSONDecoder().decode(Answer.self, from: data).answer
    }

    ///Parses /v1/health?symbols=, keyed by the symbol the server echoes (uppercased).
    static func parseBatch(_ data: Data) throws -> [String: StockHealthAnswer] {
        let batch = try JSONDecoder().decode(Batch.self, from: data)
        var answers: [String: StockHealthAnswer] = [:]
        for item in batch.health {
            answers[item.symbol] = item.answer
        }
        return answers
    }
}
