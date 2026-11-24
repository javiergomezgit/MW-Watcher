//
//  HealthExplanationController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///The sheet behind a row of the chart screen's Health card (BS-310): what that number means in
///plain words, this stock's figures, and the rule behind them. The distance from the high comes
///with a recovery calculator, because a fall and the rise that undoes it are not the same size.
///
///Styled like `AnalystTargetController` and `TrendExplanationController`. It describes past
///prices only and says so; nothing here is buy or sell.
final class HealthExplanationController: UIViewController {

    private let ticker: String
    private let health: StockHealth
    private let topic: HealthTopic
    ///The chart screen's formatter: $ for a stock, points for an index.
    private let priceText: (Double) -> String

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(ticker: String, health: StockHealth, topic: HealthTopic, priceText: @escaping (Double) -> String) {
        self.ticker = ticker
        self.health = health
        self.topic = topic
        self.priceText = priceText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("HealthExplanationController is built in code")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "colorPrimary")
        title = topic.title
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

        stack.addArrangedSubview(Self.label(ticker, font: Self.heavy(24)))
        switch topic {
        case .label: addLabelSections()
        case .trend: addTrendSections()
        case .fromHigh: addFromHighSections()
        case .risk: addRiskSections()
        case .momentum: addMomentumSections()
        }
        stack.addArrangedSubview(Self.label(
            StockHealthFormat.asOf(health) + ". It describes past prices only and isn't advice to buy or sell.",
            font: Self.medium(12), color: Self.secondaryColor))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Topics

    ///The overall label, and the four labels with the rule for each (the server's HEALTH_RULES).
    private func addLabelSections() {
        stack.addArrangedSubview(Self.card([
            Self.caption("\(ticker.uppercased()) IS"),
            Self.label(StockHealthFormat.title(for: health.label), font: Self.heavy(30),
                       color: StockHealthFormat.color(for: health.label)),
            Self.label(StockHealthFormat.explanation(for: health), font: Self.medium(15))
        ]))
        let labels: [(HealthLabel, String)] = [
            (.healthy, "In an uptrend and no more than 20% below its 52-week high."),
            (.attention, "In an uptrend but more than 20% below its 52-week high, or the trend broke in the last 30 days."),
            (.weak, "The trend broke more than 30 days ago and hasn't come back."),
            (.recovering, "In an uptrend, but still more than 50% below its all-time high.")
        ]
        var rows: [UIView] = [Self.caption("THE FOUR LABELS")]
        for (label, rule) in labels {
            let name = Self.label(StockHealthFormat.title(for: label), font: Self.heavy(15),
                                  color: StockHealthFormat.color(for: label))
            rows.append(Self.column([name, Self.label(rule, font: Self.medium(14), color: Self.secondaryColor)], spacing: 2))
        }
        rows.append(Self.label("The label sums up the trend and the distance from the high. There's no score: each part is on the card so you can judge it yourself.",
                               font: Self.medium(14)))
        stack.addArrangedSubview(Self.card(rows))
    }

    private func addTrendSections() {
        stack.addArrangedSubview(Self.card([
            Self.caption("THE TREND"),
            Self.label(StockHealthFormat.trend(health.trend, historyDays: health.historyDays), font: Self.heavy(20)),
            Self.valueRow("Last close", priceText(health.close)),
            Self.valueRow("50-day average", priceText(health.sma50)),
            Self.valueRow("200-day average", priceText(health.sma200)),
            Self.label("The close is " + StockHealthFormat.versus200(health.pctVs200) + ".", font: Self.medium(15))
        ]))
        stack.addArrangedSubview(Self.card([
            Self.caption("WHAT IT MEANS"),
            Self.bullet("The 200-day average is the average of the last 200 closing prices, about ten months of trading. It smooths out day-to-day moves."),
            Self.bullet("Uptrend: the stock closes above that average. Trend break: it closes below it."),
            Self.bullet("A change only counts after two closes in a row on the new side, so one noisy day doesn't flip it."),
            Self.bullet("The 50-day average is the same idea over about ten weeks, and turns sooner.")
        ]))
    }

    ///The distance from the all-time high, and the recovery calculator.
    private func addFromHighSections() {
        stack.addArrangedSubview(Self.card([
            Self.caption("FROM ITS HIGH"),
            Self.label(StockHealthFormat.fromHigh(health), font: Self.heavy(18)),
            Self.valueRow("All-time high", priceText(health.allTimeHigh.value) + " · " + StockHealthFormat.day(health.allTimeHigh.date)),
            Self.valueRow("52-week high", priceText(health.high52w.value) + " · " + StockHealthFormat.day(health.high52w.date)),
            Self.valueRow("52-week low", priceText(health.low52w.value) + " · " + StockHealthFormat.day(health.low52w.date)),
            Self.valueRow("Last close", priceText(health.close))
        ]))

        var rows: [UIView] = [
            Self.caption("RECOVERY CALCULATOR"),
            Self.label("A fall takes a bigger rise to undo: after a 50% drop, the price has to double to get back.",
                       font: Self.medium(15)),
            Self.tableRow("Drop", "Rise needed to get back", heading: true)
        ]
        let drops: [Double] = [-0.10, -0.20, -0.30, -0.40, -0.50, -0.60, -0.75, -0.90]
        let own = health.pctFromHigh
        var ownShown = own > -0.005
        for drop in drops {
            //This stock's own row goes in its place in the table, highlighted.
            if !ownShown, own > drop {
                rows.append(Self.tableRow(StockHealthFormat.percent(own) + " (\(ticker))",
                                          StockHealthFormat.percent(health.recoveryNeeded, digits: health.recoveryNeeded >= 1 ? 0 : 1),
                                          highlighted: true))
                ownShown = true
            }
            rows.append(Self.tableRow(StockHealthFormat.percent(drop, digits: 0),
                                      StockHealthFormat.percent(1 / (1 + drop) - 1, digits: 0)))
        }
        if !ownShown {
            rows.append(Self.tableRow(StockHealthFormat.percent(own) + " (\(ticker))",
                                      StockHealthFormat.percent(health.recoveryNeeded, digits: 0),
                                      highlighted: true))
        }
        stack.addArrangedSubview(Self.card(rows))
    }

    private func addRiskSections() {
        var swings: [UIView] = [Self.caption("HOW MUCH IT SWINGS")]
        if let text = StockHealthFormat.volatility(health.volatility, market: health.marketVolatility) {
            swings.append(Self.label(text, font: Self.heavy(20)))
        } else {
            swings.append(Self.label("Not enough history yet", font: Self.heavy(20), color: Self.secondaryColor))
        }
        swings.append(Self.label("Volatility is how much the price typically moves over a year, from its daily moves in the last 252 trading days. 25% means a normal year can easily see the price 25% higher or lower. The S&P 500 is shown on the same basis for comparison.",
                                 font: Self.medium(15)))
        stack.addArrangedSubview(Self.card(swings))

        var worst: [UIView] = [Self.caption("WORST DROP")]
        if let drop = health.worstDrop {
            worst.append(Self.label(StockHealthFormat.percent(drop.depth), font: Self.heavy(20)))
            worst.append(Self.valueRow("Peak", priceText(drop.peak.value) + " · " + StockHealthFormat.day(drop.peak.date)))
            worst.append(Self.valueRow("Bottom", priceText(drop.trough.value) + " · " + StockHealthFormat.day(drop.trough.date)))
            if let recovered = drop.recoveredOn, let days = drop.daysToRecover {
                worst.append(Self.valueRow("Back to the peak", StockHealthFormat.day(recovered)))
                worst.append(Self.label("It took \(days) trading day\(days == 1 ? "" : "s") from the bottom to get back.",
                                        font: Self.medium(15)))
            } else {
                worst.append(Self.label("It hasn't got back to that peak yet.", font: Self.medium(15)))
            }
        } else {
            worst.append(Self.label("It has never fallen from a peak in the history there is.", font: Self.medium(15)))
        }
        worst.append(Self.label("The deepest fall from a high to a low in up to ten years of closes. It shows what holding it has felt like at its worst.",
                                font: Self.medium(14), color: Self.secondaryColor))
        stack.addArrangedSubview(Self.card(worst))
    }

    private func addMomentumSections() {
        var rows: [UIView] = [Self.caption("MOMENTUM")]
        let word = StockHealthFormat.rsi(health.rsiWord) ?? "Not enough history"
        rows.append(Self.label(word, font: Self.heavy(20)))
        if let rsi = health.rsi14 {
            rows.append(Self.valueRow("RSI (14 days)", String(format: "%.0f of 100", rsi)))
        }
        if let oneYear = StockHealthFormat.oneYearReturn(health.return1y) {
            rows.append(Self.valueRow("Last year", oneYear.replacingOccurrences(of: " in the last year", with: "")))
        }
        stack.addArrangedSubview(Self.card(rows))
        stack.addArrangedSubview(Self.card([
            Self.caption("WHAT IT MEANS"),
            Self.bullet("RSI compares the size of the up days with the down days over the last 14 trading days, on a 0 to 100 scale."),
            Self.bullet("Under 30 is called oversold: it has fallen fast. Over 70 is overbought: it has risen fast. In between is neutral."),
            Self.bullet("It describes the recent pace, not where the price goes next."),
            Self.bullet("The 1-year change is the price only, without dividends.")
        ]))
    }

    // MARK: - Building blocks

    private static let secondaryColor = UIColor(named: "colorSecondary") ?? .secondaryLabel

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

    private static func bullet(_ text: String) -> UILabel {
        label("• " + text, font: medium(15))
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

    ///One line of the recovery calculator.
    private static func tableRow(_ left: String, _ right: String, heading: Bool = false, highlighted: Bool = false) -> UIView {
        let color: UIColor = heading ? secondaryColor : .label
        let font = heading ? heavy(12) : (highlighted ? heavy(15) : medium(15))
        let leftLabel = label(left, font: font, color: color)
        let rightLabel = label(right, font: font, color: color)
        rightLabel.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [leftLabel, rightLabel])
        row.distribution = .fillEqually
        row.isAccessibilityElement = true
        row.accessibilityLabel = heading ? nil : "A drop of \(left) needs a rise of \(right)"
        guard highlighted else { return row }
        let box = UIView()
        box.backgroundColor = UIColor.systemFill
        box.layer.cornerRadius = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -6)
        ])
        return box
    }

    private static func column(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let column = UIStackView(arrangedSubviews: views)
        column.axis = .vertical
        column.spacing = spacing
        return column
    }

    private static func card(_ views: [UIView]) -> UIView {
        let content = column(views, spacing: 10)
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
