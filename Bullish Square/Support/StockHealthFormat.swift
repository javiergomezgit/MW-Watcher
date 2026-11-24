//
//  StockHealthFormat.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///Every word, symbol and colour for stock health (BS-308), in one place like
///`AnalystTargetFormat`, so the watchlist, the stock screen and later the email say the same thing.
///
///Wording rules (Calm Investing §9): states, never instructions. Nothing here says buy, sell or
///hold, so health can't be read as a second analyst consensus. Numbers come as fractions from
///the server and are shown as signed percents.
enum StockHealthFormat {

    // MARK: - Label

    static func title(for label: HealthLabel) -> String {
        switch label {
        case .healthy: return "Healthy"
        case .attention: return "Attention"
        case .weak: return "Weak"
        case .recovering: return "Recovering"
        }
    }

    ///SF Symbols, so the state also reads without colour.
    static func symbolName(for label: HealthLabel) -> String {
        switch label {
        case .healthy: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .weak: return "xmark.circle.fill"
        case .recovering: return "arrow.uturn.up.circle.fill"
        }
    }

    ///Healthy and weak reuse the app's uptrend and downtrend colours: they are trend states.
    ///Attention is orange and recovering is purple, both clear of the analyst blues, slate and
    ///yellows in `AnalystTargetFormat.ratingColor`.
    static func color(for label: HealthLabel) -> UIColor {
        switch label {
        case .healthy: return UIColor(named: "uptrend") ?? .systemGreen
        case .attention: return UIColor(red: 1.00, green: 0.58, blue: 0.24, alpha: 1)
        case .weak: return UIColor(named: "downtrend") ?? .systemRed
        case .recovering: return UIColor(red: 0.72, green: 0.56, blue: 1.00, alpha: 1)
        }
    }

    ///One plain sentence on why the stock has this label.
    static func explanation(for health: StockHealth) -> String {
        switch health.label {
        case .healthy:
            return "In an uptrend and within 20% of its 52-week high."
        case .attention:
            if health.trend.state == .downtrend {
                return "The trend broke recently. Has the business changed, or just the price?"
            }
            return "In an uptrend, but more than 20% below its 52-week high."
        case .weak:
            return "Below its 200-day average for more than 30 days."
        case .recovering:
            return "In an uptrend, but still \(percent(health.pctFromHigh)) from its all-time high."
        }
    }

    ///What a symbol without health shows in its place.
    static func placeholder(for answer: StockHealthAnswer) -> String? {
        switch answer {
        case .health: return nil
        case .insufficientHistory: return "Not enough history yet"
        case .noData: return "No price history"
        case .unavailable: return "Health unavailable right now"
        }
    }

    // MARK: - Watchlist badge (BS-309)

    ///What a watchlist row's trend badge shows. A state, never an instruction: "Uptrend" while
    ///the close holds above the 200-day average, "Trend break" once it has closed below it twice,
    ///"New" for a listing with under 200 closes. Anything else (loading, failed, unknown symbol)
    ///is a grey dash, so the row never waits on health and never jumps when it lands.
    struct Badge: Equatable {
        let text: String
        let symbolName: String?
        let color: UIColor
        let accessibilityLabel: String
    }

    static func badge(for answer: StockHealthAnswer?) -> Badge {
        switch answer {
        case .health(let health) where health.trend.state == .uptrend:
            return Badge(text: "Uptrend", symbolName: "arrow.up.right",
                         color: UIColor(named: "uptrend") ?? .systemGreen,
                         accessibilityLabel: trend(health.trend, historyDays: health.historyDays))
        case .health(let health):
            //`downtrend` itself is too dark to read as small text on the row, like the change pill.
            return Badge(text: "Trend break", symbolName: "arrow.down.right",
                         color: UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1),
                         accessibilityLabel: trend(health.trend, historyDays: health.historyDays))
        case .insufficientHistory:
            return Badge(text: "New", symbolName: nil, color: .secondaryLabel,
                         accessibilityLabel: "Not enough history yet")
        case .noData, .unavailable, nil:
            return Badge(text: "—", symbolName: nil, color: .tertiaryLabel,
                         accessibilityLabel: "Trend not available")
        }
    }

    // MARK: - Components

    ///"Uptrend since 11 Aug 2025", "Trend break on 20 Nov 2026", or, when the trend has held
    ///for all the history there is, "Uptrend for 10 years or more".
    static func trend(_ trend: StockHealth.Trend, historyDays: Int) -> String {
        let name = trend.state == .uptrend ? "Uptrend" : "Downtrend"
        if trend.sinceIsStartOfData {
            let years = historyDays / 252
            return years >= 1 ? "\(name) for \(years) year\(years == 1 ? "" : "s") or more" : name
        }
        let date = day(trend.since)
        return trend.state == .uptrend ? "\(name) since \(date)" : "Trend break on \(date)"
    }

    ///"12.4% above its 200-day average".
    static func versus200(_ pct: Double) -> String {
        let side = pct >= 0 ? "above" : "below"
        return "\(unsignedPercent(pct)) \(side) its 200-day average"
    }

    ///"-38.7% from its high · needs +63.1% to get back", or "At its all-time high".
    static func fromHigh(_ health: StockHealth) -> String {
        //Under half a percent rounds to "-0%", which reads as a bug.
        guard health.pctFromHigh <= -0.005 else { return "At its all-time high" }
        //"+3,024%", not "+3,023.5%": past 100% the decimal is noise.
        let needed = percent(health.recoveryNeeded, digits: health.recoveryNeeded >= 1 ? 0 : 1)
        return "\(percent(health.pctFromHigh)) from its high · needs \(needed) to get back"
    }

    ///"25% a year (S&P 500: 14%)".
    static func volatility(_ value: Double?, market: Double?) -> String? {
        guard let value else { return nil }
        let own = "\(unsignedPercent(value, digits: 0)) a year"
        guard let market else { return own }
        return "\(own) (S&P 500: \(unsignedPercent(market, digits: 0)))"
    }

    ///"-38.7%, Oct 2018 to Jan 2019, recovered in 195 trading days", or "not recovered yet".
    static func worstDrop(_ drop: StockHealth.WorstDrop?) -> String? {
        guard let drop else { return nil }
        let span = "\(percent(drop.depth)), \(month(drop.peak.date)) to \(month(drop.trough.date))"
        guard let days = drop.daysToRecover else { return "\(span), not recovered yet" }
        return "\(span), recovered in \(days) trading day\(days == 1 ? "" : "s")"
    }

    static func rsi(_ word: RsiWord?) -> String? {
        switch word {
        case .oversold: return "Oversold"
        case .neutral: return "Neutral"
        case .overbought: return "Overbought"
        case nil: return nil
        }
    }

    ///"+18.2% in the last year (price only)".
    static func oneYearReturn(_ value: Double?) -> String? {
        guard let value else { return nil }
        return "\(percent(value)) in the last year (price only)"
    }

    ///"As of 13 Nov 2026 close": how fresh the numbers are, shown with every health view.
    static func asOf(_ health: StockHealth) -> String {
        "As of \(day(health.asOf)) close"
    }

    // MARK: - Numbers and dates

    ///A fraction as a signed percent with one decimal: -0.387 is "-38.7%". Thousands separated,
    ///because a recovery needed can be "+2,837%".
    static func percent(_ fraction: Double, digits: Int = 1) -> String {
        let text = unsignedPercent(fraction, digits: digits)
        let scale = pow(10, Double(digits))
        let rounded = (fraction * 100 * scale).rounded() / scale
        return rounded > 0 ? "+" + text : (rounded < 0 ? "-" + text : text)
    }

    ///A fraction as a percent without a sign, for words that already say the direction.
    static func unsignedPercent(_ fraction: Double, digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.roundingMode = .halfUp
        let value = abs(fraction * 100)
        return (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)) + "%"
    }

    ///The server's "yyyy-MM-dd" New York trading day. Parsed and printed in UTC so the day never
    ///shifts with the phone's time zone.
    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func printer(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }

    private static let dayPrinter = printer("d MMM yyyy")
    private static let monthPrinter = printer("MMM yyyy")

    ///"13 Nov 2026". An unreadable date is shown as sent rather than hidden.
    static func day(_ iso: String) -> String {
        guard let date = isoDay.date(from: iso) else { return iso }
        return dayPrinter.string(from: date)
    }

    ///"Oct 2018".
    static func month(_ iso: String) -> String {
        guard let date = isoDay.date(from: iso) else { return iso }
        return monthPrinter.string(from: date)
    }
}
