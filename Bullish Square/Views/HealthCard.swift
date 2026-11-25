//
//  HealthCard.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///One part of a stock's health that the user can tap for a plain-language explanation (BS-310).
enum HealthTopic: CaseIterable {
    case label
    case trend
    case fromHigh
    case risk
    case momentum

    var title: String {
        switch self {
        case .label: return "Health"
        case .trend: return "Trend"
        case .fromHigh: return "From its high"
        case .risk: return "Risk"
        case .momentum: return "Momentum"
        }
    }
}

///The Health card on a stock's chart screen (BS-310), between Key stats and Analysts: the
///overall label with its one-sentence reason, then each component on its own row (trend,
///distance from the high, risk, momentum) and how fresh the numbers are. Every row opens
///`HealthExplanationController`.
///
///There is deliberately no score: the label is a description the server works out from the
///components, and the components are shown separately so none of them hides behind it.
final class HealthCard: UIView {

    ///Set by the chart screen; the card only says which row was tapped.
    var onSelect: ((HealthTopic) -> Void)?
    ///The bell beside the heading was tapped (BS-314).
    var onBell: (() -> Void)?

    ///What the bell says about this stock's trend alerts.
    enum AlertState {
        case on, muted, off
    }

    private let bell = UIButton(type: .system)

    private let rowsStack = UIStackView()
    private let freshnessLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        let heading = UILabel()
        heading.text = "Health"
        heading.font = UIFont.preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .label

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous

        rowsStack.axis = .vertical
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])

        freshnessLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        freshnessLabel.adjustsFontForContentSizeCategory = true
        freshnessLabel.textColor = .secondaryLabel
        freshnessLabel.numberOfLines = 0

        //Hidden until the chart screen knows the person's settings; signed out it stays hidden.
        bell.isHidden = true
        bell.setContentHuggingPriority(.required, for: .horizontal)
        bell.addAction(UIAction { [weak self] _ in self?.onBell?() }, for: .touchUpInside)
        let headingRow = UIStackView(arrangedSubviews: [heading, bell])
        headingRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [headingRow, card, freshnessLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    ///nil hides the bell (signed out). `.off` means trend alerts are off in Settings altogether.
    func showAlerts(_ state: AlertState?) {
        guard let state else {
            bell.isHidden = true
            return
        }
        let symbol: String
        let label: String
        switch state {
        case .on:
            symbol = "bell.fill"
            label = "Trend alerts on for this stock"
            bell.tintColor = .label
        case .muted:
            symbol = "bell.slash"
            label = "Trend alerts muted for this stock"
            bell.tintColor = .secondaryLabel
        case .off:
            symbol = "bell"
            label = "Trend alerts are off"
            bell.tintColor = .secondaryLabel
        }
        bell.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)), for: .normal)
        bell.accessibilityLabel = label
        bell.accessibilityHint = state == .off ? "Opens notification settings" : "Mutes or unmutes this stock's trend alerts"
        bell.isHidden = false
    }

    ///A health answer, or a sentence in its place ("Not enough history yet"). `priceText`
    ///formats prices like the rest of the screen ($ for a stock, points for an index).
    ///
    ///`change` comes from the watchlist's last review (BS-311): what changed since the last
    ///visit, "" for no change, nil for a stock the active watchlist doesn't hold.
    func update(_ answer: StockHealthAnswer, priceText: (Double) -> String, change: String? = nil) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let health = answer.health else {
            let text = StockHealthFormat.placeholder(for: answer) ?? "Health unavailable right now"
            let row = HealthRow(title: nil, value: text, detail: nil, valueColor: .secondaryLabel,
                                symbolName: nil, tappable: false)
            rowsStack.addArrangedSubview(row)
            freshnessLabel.text = nil
            freshnessLabel.isHidden = true
            return
        }

        let label = HealthRow(title: nil,
                              value: StockHealthFormat.title(for: health.label),
                              detail: StockHealthFormat.explanation(for: health),
                              valueColor: StockHealthFormat.color(for: health.label),
                              symbolName: StockHealthFormat.symbolName(for: health.label),
                              tappable: true, large: true)
        add(label, topic: .label, separator: true)

        add(HealthRow(title: HealthTopic.trend.title,
                      value: StockHealthFormat.trend(health.trend, historyDays: health.historyDays),
                      detail: StockHealthFormat.versus200(health.pctVs200).capitalizedFirst),
            topic: .trend, separator: true)

        add(HealthRow(title: HealthTopic.fromHigh.title,
                      value: StockHealthFormat.fromHigh(health),
                      detail: "All-time high " + priceText(health.allTimeHigh.value)
                        + " on " + StockHealthFormat.day(health.allTimeHigh.date)),
            topic: .fromHigh, separator: true)

        let swings = StockHealthFormat.volatility(health.volatility, market: health.marketVolatility)
            .map { "Swings about " + $0 } ?? "Not enough history for volatility"
        let worst = StockHealthFormat.worstDrop(health.worstDrop).map { "Worst drop " + $0 }
        add(HealthRow(title: HealthTopic.risk.title, value: swings, detail: worst),
            topic: .risk, separator: true)

        var momentum = StockHealthFormat.rsi(health.rsiWord) ?? "Not enough history"
        if let rsi = health.rsi14 {
            momentum += String(format: " (RSI %.0f)", rsi)
        }
        add(HealthRow(title: HealthTopic.momentum.title, value: momentum,
                      detail: StockHealthFormat.oneYearReturn(health.return1y)?.capitalizedFirst),
            topic: .momentum, separator: false)

        var freshness = StockHealthFormat.asOf(health) + ". Describes past prices only; not advice to buy or sell."
        if let change {
            freshness = (change.isEmpty ? "✓ No change detected since your last visit. "
                                        : "● Changed since your last visit: \(change). ") + freshness
        }
        freshnessLabel.text = freshness
        freshnessLabel.isHidden = false
    }

    private func add(_ row: HealthRow, topic: HealthTopic, separator: Bool) {
        row.addAction(UIAction { [weak self] _ in self?.onSelect?(topic) }, for: .touchUpInside)
        row.showsSeparator = separator
        rowsStack.addArrangedSubview(row)
    }
}

///One tappable line of the Health card: a small title, the value, an optional second line and
///a chevron. Highlights under the finger like a table row.
private final class HealthRow: UIControl {

    var showsSeparator = false {
        didSet { hairline.isHidden = !showsSeparator }
    }

    private let hairline = UIView()

    init(title: String?, value: String, detail: String?, valueColor: UIColor = .label,
         symbolName: String? = nil, tappable: Bool = true, large: Bool = false) {
        super.init(frame: .zero)

        var lines: [UIView] = []
        if let title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.textColor = .secondaryLabel
            lines.append(titleLabel)
        }

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = large
            ? UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .bold))
            : UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = valueColor
        valueLabel.numberOfLines = 0

        if let symbolName {
            let symbol = UIImageView(image: UIImage(systemName: symbolName))
            symbol.tintColor = valueColor
            symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
            symbol.setContentHuggingPriority(.required, for: .horizontal)
            let line = UIStackView(arrangedSubviews: [symbol, valueLabel])
            line.spacing = 6
            line.alignment = .center
            lines.append(line)
        } else {
            lines.append(valueLabel)
        }

        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            detailLabel.adjustsFontForContentSizeCategory = true
            detailLabel.textColor = .secondaryLabel
            detailLabel.numberOfLines = 0
            lines.append(detailLabel)
        }

        let text = UIStackView(arrangedSubviews: lines)
        text.axis = .vertical
        text.spacing = 3

        var parts: [UIView] = [text]
        if tappable {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = .tertiaryLabel
            chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
            parts.append(chevron)
        }
        let row = UIStackView(arrangedSubviews: parts)
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        hairline.backgroundColor = .separator
        hairline.isHidden = true
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hairline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        isEnabled = tappable
        isAccessibilityElement = true
        accessibilityTraits = tappable ? .button : .staticText
        accessibilityLabel = [title, value, detail].compactMap { $0 }.joined(separator: ". ")
    }

    required init?(coder: NSCoder) {
        fatalError("HealthRow is built in code")
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor.systemFill : .clear }
    }
}

private extension String {
    ///"12.4% above its 200-day average" reads as a sentence on its own line.
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
