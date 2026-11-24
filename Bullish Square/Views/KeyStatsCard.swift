//
//  KeyStatsCard.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///The Key stats card under the chart (BS-327): a heading, then two columns of name and value,
///like the stats under a stock in Apple's Stocks. The values arrive later than the card; until
///then each shows a dash, so the card never changes height when they land.
final class KeyStatsCard: UIView {

    ///Each row's name and value labels, left column then right, in `rows` order.
    private var valueLabels: [UILabel] = []

    ///The two columns, top to bottom. Names are fixed; values are set with `update`.
    static let rows: [(left: String, right: String)] = [
        ("Open", "52W high"),
        ("High", "52W low"),
        ("Low", "Avg vol (3M)"),
        ("Volume", "1Y change")
    ]

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
        heading.text = "Key stats"
        heading.font = UIFont.preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .label

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous

        let left = UIStackView()
        let right = UIStackView()
        for column in [left, right] {
            column.axis = .vertical
            column.spacing = 0
        }
        var leftValues: [UILabel] = []
        var rightValues: [UILabel] = []
        for (index, row) in Self.rows.enumerated() {
            let last = index == Self.rows.count - 1
            let (leftRow, leftValue) = Self.statRow(name: row.left, separator: !last)
            let (rightRow, rightValue) = Self.statRow(name: row.right, separator: !last)
            left.addArrangedSubview(leftRow)
            right.addArrangedSubview(rightRow)
            leftValues.append(leftValue)
            rightValues.append(rightValue)
        }
        valueLabels = leftValues + rightValues

        let columns = UIStackView(arrangedSubviews: [left, right])
        columns.spacing = 20
        columns.distribution = .fillEqually
        columns.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(columns)
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            columns.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
            columns.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            columns.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])

        let stack = UIStackView(arrangedSubviews: [heading, card])
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
        update(KeyStats(), priceText: { _ in "—" })
    }

    ///One "Open ...... $348.06" row with a hairline under it, except the last.
    private static func statRow(name: String, separator: Bool) -> (UIView, UILabel) {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = .secondaryLabel
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        let base = UIFont.preferredFont(forTextStyle: .subheadline)
        valueLabel.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .semibold))
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7

        let line = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        line.spacing = 8
        line.alignment = .firstBaseline
        line.isLayoutMarginsRelativeArrangement = true
        line.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        line.isAccessibilityElement = true
        line.accessibilityLabel = name

        guard separator else { return (line, valueLabel) }
        let hairline = UIView()
        hairline.backgroundColor = .separator
        hairline.translatesAutoresizingMaskIntoConstraints = false
        line.addSubview(hairline)
        NSLayoutConstraint.activate([
            hairline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            hairline.leadingAnchor.constraint(equalTo: line.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: line.trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: line.bottomAnchor)
        ])
        return (line, valueLabel)
    }

    ///Shows the stats. `priceText` formats prices the way the rest of the screen does ($ for a
    ///stock, points for an index).
    func update(_ stats: KeyStats, priceText: (Double) -> String) {
        let dash = "—"
        //Formatted in place: keeping `priceText` in a local closure makes Swift treat it as
        //escaping, which a non-escaping parameter can't be.
        var prices: [String] = []
        for value in [stats.open, stats.high, stats.low, stats.high52w, stats.low52w] {
            prices.append(value.map { priceText($0) } ?? dash)
        }
        let volume = stats.volume.map(KeyStats.compactVolume) ?? dash
        let averageVolume = stats.averageVolume3m.map(KeyStats.compactVolume) ?? dash
        let change: String = stats.change1y.map {
            let rounded = ($0 * 10).rounded() / 10
            return String(format: "%@%.1f%%", rounded > 0 ? "+" : (rounded < 0 ? "-" : ""), abs(rounded))
        } ?? dash
        let values = [prices[0], prices[1], prices[2], volume, prices[3], prices[4], averageVolume, change]
        for (label, text) in zip(valueLabels, values) {
            label.text = text
            label.superview?.accessibilityValue = text
        }
        //The 1Y change in green or red, like every change on the screen.
        if let change1y = stats.change1y, let changeLabel = valueLabels.last {
            changeLabel.textColor = change1y < 0 ? (UIColor(named: "downtrend") ?? .systemRed)
                                                 : (UIColor(named: "uptrend") ?? .systemGreen)
        }
    }
}
