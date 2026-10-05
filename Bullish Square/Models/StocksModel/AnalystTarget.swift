//
//  AnalystTarget.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/30/26.
//

import Foundation

///Wall Street analysts' consensus for one stock: where they expect the price to be in about a
///year, and how many rate it a buy, hold or sell.
///
///This is a third-party estimate the app reports, never a valuation the app makes. Nothing here
///computes "undervalued"; the upside is only the gap between the average target and today's
///price.
struct AnalystTarget: Codable, Equatable {
    let meanTarget: Double
    let lowTarget: Double?
    let highTarget: Double?
    ///Analysts behind the price target. Yahoo counts these separately from the ratings in
    ///`breakdown`, and the two rarely agree (AAPL: 39 targets, 44 ratings), so they are never
    ///shown as one number.
    let analystCount: Int?
    ///Yahoo's key, such as "buy" or "strong_buy".
    let recommendationKey: String?
    ///1 is strong buy, 5 is strong sell.
    let recommendationMean: Double?
    let breakdown: Breakdown?

    ///The current month's ratings.
    struct Breakdown: Codable, Equatable {
        let strongBuy: Int
        let buy: Int
        let hold: Int
        let sell: Int
        let strongSell: Int

        var total: Int { strongBuy + buy + hold + sell + strongSell }
    }

    // MARK: - Reading

    ///Upside is always measured against today's price: (target - price) / price, as a percent.
    ///Measuring the same gap against the target gives a different number (ZM: +34% against the
    ///price, 25% against the target), so there is only ever this one convention.
    func upsidePercent(from price: Double) -> Double? {
        guard price > 0 else { return nil }
        return (meanTarget - price) / price * 100
    }

    ///The average rating on the 1 (strong buy) to 5 (strong sell) scale, worked out from the
    ///counts the sheet shows. Yahoo's own `recommendationMean` comes from a different set of
    ///analysts: APLE had 3 buy and 8 hold this month (2.7, a hold) while Yahoo said "buy".
    ///Using the counts keeps the word, its colour and the bars in agreement. Yahoo's figure
    ///is only the fallback for a stock with no counts.
    var consensusMean: Double? {
        guard let breakdown, breakdown.total > 0 else { return recommendationMean }
        let weighted = 1 * breakdown.strongBuy + 2 * breakdown.buy + 3 * breakdown.hold
            + 4 * breakdown.sell + 5 * breakdown.strongSell
        return Double(weighted) / Double(breakdown.total)
    }

    ///The consensus as a key ("strong_buy" ... "strong_sell"), from `consensusMean` with the
    ///usual half-point bands; Yahoo's key when there is no mean at all.
    var consensusKey: String? {
        guard let mean = consensusMean else { return recommendationKey }
        switch mean {
        case ..<1.5: return "strong_buy"
        case ..<2.5: return "buy"
        case ..<3.5: return "hold"
        case ..<4.5: return "sell"
        default: return "strong_sell"
        }
    }

    ///Readable form of `consensusKey`, or nil for one that says nothing ("none").
    var consensusLabel: String? {
        switch consensusKey {
        case "strong_buy": return "Strong Buy"
        case "buy": return "Buy"
        case "hold": return "Hold"
        case "underperform": return "Underperform"
        case "sell": return "Sell"
        case "strong_sell": return "Strong Sell"
        default: return nil
        }
    }

    // MARK: - Parsing

    enum ParseError: Error {
        case unexpectedShape
    }

    ///Yahoo wraps each number as {"raw": 118.24, "fmt": "118.24"}; only `raw` is read.
    private struct Raw<Value: Decodable>: Decodable {
        let raw: Value?
    }

    private struct Response: Decodable {
        let quoteSummary: QuoteSummary?

        struct QuoteSummary: Decodable {
            let result: [Result]?
        }

        struct Result: Decodable {
            let financialData: FinancialData?
            let recommendationTrend: RecommendationTrend?
        }

        struct FinancialData: Decodable {
            let targetMeanPrice: Raw<Double>?
            let targetLowPrice: Raw<Double>?
            let targetHighPrice: Raw<Double>?
            let numberOfAnalystOpinions: Raw<Int>?
            let recommendationKey: String?
            let recommendationMean: Raw<Double>?
        }

        struct RecommendationTrend: Decodable {
            let trend: [Period]?
        }

        struct Period: Decodable {
            let period: String?
            let strongBuy: Int?
            let buy: Int?
            let hold: Int?
            let sell: Int?
            let strongSell: Int?
        }
    }

    ///Parses the server's /v1/fundamentals body, which is Yahoo's quoteSummary unchanged.
    ///
    ///Throws rather than returning nil when the mean target is missing: the server answers 404
    ///for a stock without coverage, so a 200 without a target means the format changed, and that
    ///should be loud rather than quietly read as "no analysts".
    static func parse(_ data: Data) throws -> AnalystTarget {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let result = response.quoteSummary?.result?.first,
              let financial = result.financialData,
              let mean = financial.targetMeanPrice?.raw else {
            throw ParseError.unexpectedShape
        }

        //"0m" is the current month; the rest are the three before it.
        let current = result.recommendationTrend?.trend?.first { $0.period == "0m" }
        let breakdown = current.map {
            Breakdown(strongBuy: $0.strongBuy ?? 0, buy: $0.buy ?? 0, hold: $0.hold ?? 0,
                      sell: $0.sell ?? 0, strongSell: $0.strongSell ?? 0)
        }

        return AnalystTarget(meanTarget: mean,
                             lowTarget: financial.targetLowPrice?.raw,
                             highTarget: financial.targetHighPrice?.raw,
                             analystCount: financial.numberOfAnalystOpinions?.raw,
                             recommendationKey: financial.recommendationKey,
                             recommendationMean: financial.recommendationMean?.raw,
                             //A month with no ratings at all is no breakdown, not a bar of zeros.
                             breakdown: (breakdown?.total ?? 0) > 0 ? breakdown : nil)
    }
}
