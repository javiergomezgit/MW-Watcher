//
//  TrendExplanationController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///The sheet behind a watchlist row's trend badge (BS-309): what the badge says, the numbers it
///came from, and the rule that turned them into a word, so "Uptrend" or "Trend break" is
///something the user can check rather than take on trust.
///
///Built in code like `AnalystTargetController`, and styled to match it, since the two sheets open
///from the same row. It describes past prices only and says so; nothing here is buy or sell.
final class TrendExplanationController: UIViewController {

    private let ticker: String
    private let companyName: String
    ///nil while health is loading or failed; the sheet then explains the dash instead.
    private let answer: StockHealthAnswer?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(ticker: String, companyName: String, answer: StockHealthAnswer?) {
        self.ticker = ticker
        self.companyName = companyName
        self.answer = answer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("TrendExplanationController is built in code")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "colorPrimary")
        title = "Trend"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])

        stack.addArrangedSubview(headerSection())
        if let health = answer?.health {
            stack.addArrangedSubview(verdictSection(health))
            stack.addArrangedSubview(numbersSection(health))
        } else {
            stack.addArrangedSubview(missingSection())
        }
        stack.addArrangedSubview(ruleSection())
        stack.addArrangedSubview(footerSection())
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Sections

    private func headerSection() -> UIView {
        let tickerLabel = Self.label(ticker, font: Self.heavy(24))
        let nameLabel = Self.label(companyName, font: Self.medium(15), color: Self.secondaryColor)
        return Self.column([tickerLabel, nameLabel], spacing: 2)
    }

    ///The badge's word, large and in its colour, then since when.
    private func verdictSection(_ health: StockHealth) -> UIView {
        let badge = StockHealthFormat.badge(for: answer)
        let word = Self.label(badge.text, font: Self.heavy(30), color: badge.color)
        let since = Self.label(StockHealthFormat.trend(health.trend, historyDays: health.historyDays),
                               font: Self.medium(15))
        let meaning: String
        if health.trend.state == .uptrend {
            meaning = "\(ticker) has been closing above its 200-day average price."
        } else {
            meaning = "\(ticker) has closed below its 200-day average price, which ended its uptrend."
        }
        let detail = Self.label(meaning, font: Self.medium(15), color: Self.secondaryColor)
        return Self.card(Self.column([Self.caption("WHAT THE BADGE SAYS"), word, since, detail], spacing: 8))
    }

    ///The two numbers the badge compares, and how far apart they are.
    private func numbersSection(_ health: StockHealth) -> UIView {
        var rows: [UIView] = [Self.caption("THE NUMBERS")]
        rows.append(Self.valueRow("Last close", Self.price(health.close)))
        rows.append(Self.valueRow("200-day average", Self.price(health.sma200)))
        rows.append(Self.valueRow("50-day average", Self.price(health.sma50)))
        rows.append(Self.label("The close is " + StockHealthFormat.versus200(health.pctVs200) + ".",
                               font: Self.medium(15)))
        return Self.card(Self.column(rows, spacing: 10))
    }

    ///"New" and the grey dash: why there's no trend to show.
    private func missingSection() -> UIView {
        let word: String
        let text: String
        switch answer {
        case .insufficientHistory(let days):
            word = "New"
            text = "\(ticker) has \(days) daily close\(days == 1 ? "" : "s"). A 200-day average needs at least 200, so the trend appears once it has been trading for about ten months."
        case .noData:
            word = "No trend"
            text = "There's no price history for \(ticker), so there's nothing to compare."
        case .unavailable, .health, nil:
            word = "Not available right now"
            text = "The trend couldn't be loaded. It will try again the next time the watchlist opens."
        }
        let badge = StockHealthFormat.badge(for: answer)
        return Self.card(Self.column([Self.caption("WHAT THE BADGE SAYS"),
                                      Self.label(word, font: Self.heavy(24), color: badge.color),
                                      Self.label(text, font: Self.medium(15), color: Self.secondaryColor)],
                                     spacing: 8))
    }

    ///The rule, the same for every stock (the server's HEALTH_RULES).
    private func ruleSection() -> UIView {
        let steps = [
            "The 200-day average is the average of the last 200 closing prices, about ten months of trading. It smooths out day-to-day moves.",
            "Uptrend: the stock closes above that average.",
            "Trend break: it closes below it.",
            "A change only counts after two closes in a row on the new side, so a single noisy day doesn't flip the badge."
        ]
        var rows: [UIView] = [Self.caption("HOW IT'S DECIDED")]
        for step in steps {
            rows.append(Self.label("• " + step, font: Self.medium(15)))
        }
        return Self.card(Self.column(rows, spacing: 10))
    }

    private func footerSection() -> UIView {
        var parts: [String] = []
        if let health = answer?.health {
            parts.append(StockHealthFormat.asOf(health) + ".")
        }
        parts.append("It describes past prices only and isn't advice to buy or sell.")
        return Self.label(parts.joined(separator: " "), font: Self.medium(12), color: Self.secondaryColor)
    }

    // MARK: - Building blocks

    private static let secondaryColor = UIColor(named: "colorSecondary") ?? .secondaryLabel

    ///"$1,234.56": cents kept, since the close and its averages are compared with each other.
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    private static func heavy(_ size: CGFloat) -> UIFont {
        UIFont(name: "Avenir-Heavy", size: size) ?? .boldSystemFont(ofSize: size)
    }

    private static func medium(_ size: CGFloat) -> UIFont {
        UIFont(name: "Avenir-Medium", size: size) ?? .systemFont(ofSize: size)
    }

    private static func label(_ text: String, font: UIFont, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private static func caption(_ text: String) -> UILabel {
        label(text, font: heavy(12), color: secondaryColor)
    }

    ///"Last close ........ $271.49".
    private static func valueRow(_ name: String, _ value: String) -> UIView {
        let nameLabel = label(name, font: medium(15), color: secondaryColor)
        let valueLabel = label(value, font: heavy(15))
        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        row.spacing = 8
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(name): \(value)"
        return row
    }

    private static func column(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let column = UIStackView(arrangedSubviews: views)
        column.axis = .vertical
        column.spacing = spacing
        return column
    }

    private static func card(_ content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = secondaryColor.withAlphaComponent(0.12)
        card.layer.cornerRadius = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        return card
    }
}
