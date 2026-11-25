//
//  ThesisCard.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import UIKit

///"Your Thesis" on the stock screen (BS-318): why the person watches it, the stock since they
///started, and how their own "look again if" conditions stand today. Without a thesis it offers
///to write one.
///
///Display only. Every line is a state with its date ("Happened 4 Nov 2026"), never an
///instruction; the conditions are checked here when the screen opens, and daily by BS-319.
final class ThesisCard: UIView {

    ///"Add a Reason" or the pencil: the chart screen opens the editor.
    var onEdit: (() -> Void)?
    ///"Check In" on a waiting check-in (BS-319).
    var onCheckIn: (() -> Void)?
    ///Answers shown under the conditions, newest first.
    private static let historyShown = 5

    private let rowsStack = UIStackView()
    private let editButton = UIButton(type: .system)

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
        heading.text = "Your Thesis"
        heading.font = UIFont.preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .label

        editButton.setImage(UIImage(systemName: "pencil", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)), for: .normal)
        editButton.tintColor = .secondaryLabel
        editButton.accessibilityLabel = "Edit your thesis"
        editButton.setContentHuggingPriority(.required, for: .horizontal)
        editButton.addAction(UIAction { [weak self] _ in self?.onEdit?() }, for: .touchUpInside)
        editButton.isHidden = true
        let headingRow = UIStackView(arrangedSubviews: [heading, editButton])
        headingRow.alignment = .center

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous
        rowsStack.axis = .vertical
        rowsStack.spacing = 12
        rowsStack.isLayoutMarginsRelativeArrangement = true
        rowsStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: card.topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [headingRow, card])
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

    // MARK: - States

    ///No thesis yet for this stock on this list.
    func showEmpty(ticker: String) {
        clear()
        editButton.isHidden = true
        rowsStack.addArrangedSubview(label("Why are you watching \(ticker)? A reason and what would make you look again, in your own words.",
                                           style: .subheadline, color: .secondaryLabel))
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Add a Reason"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 6
        configuration.cornerStyle = .capsule
        let add = UIButton(configuration: configuration)
        add.addAction(UIAction { [weak self] _ in self?.onEdit?() }, for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [add, UIView()])
        rowsStack.addArrangedSubview(row)
    }

    ///A thesis, with what the server knows since its start day. `health` nil shows the reason
    ///and the conditions without today's facts ("Prices unavailable right now").
    func show(_ thesis: Thesis, health: StockHealth?, priceText: (Double) -> String) {
        clear()
        editButton.isHidden = false

        //A met condition waiting for an answer comes first (BS-319).
        if let waiting = thesis.waitingCheckIn {
            rowsStack.addArrangedSubview(checkInBanner(waiting))
        }

        //Why.
        let why = NSMutableAttributedString(string: thesis.reason.title,
                                            attributes: [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.label])
        if !thesis.note.isEmpty {
            why.append(NSAttributedString(string: "\n\u{201C}\(thesis.note)\u{201D}",
                                          attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.secondaryLabel]))
        }
        rowsStack.addArrangedSubview(row(symbol: thesis.reason.symbolName, tint: .secondaryLabel, text: why))

        //Since you started watching.
        let since = health?.sinceStart
        let startPrice = thesis.startPrice ?? since?.start.value
        var sinceLines = ["Since you started watching (\(StockHealthFormat.day(thesis.startDate)))"]
        if let health, let startPrice, startPrice > 0 {
            let change = health.close / startPrice - 1
            sinceLines.append("\(priceText(startPrice)) → \(priceText(health.close))  \(StockHealthFormat.percent(change))")
            if let high = since?.high, high.value > startPrice {
                sinceLines.append("High since: \(priceText(high.value)) on \(StockHealthFormat.day(high.date))")
            }
        } else {
            sinceLines.append(health == nil ? "Prices unavailable right now" : "No close since the start day yet")
        }
        rowsStack.addArrangedSubview(label(sinceLines.joined(separator: "\n"), style: .subheadline, color: .label))

        //Look again if.
        rowsStack.addArrangedSubview(label("Look again if", style: .footnote, color: .secondaryLabel))
        let conditions = conditionRows(thesis, health: health, startPrice: startPrice)
        if conditions.isEmpty {
            rowsStack.addArrangedSubview(label("Nothing chosen. Tap the pencil to pick what would make you look again.",
                                               style: .subheadline, color: .secondaryLabel))
        }
        conditions.forEach { rowsStack.addArrangedSubview($0) }
        rowsStack.addArrangedSubview(row(symbol: "questionmark.circle", tint: .tertiaryLabel,
                                         text: attributed("Business conditions", detail: "Needs data", detailColor: .tertiaryLabel)))

        //Exit plan (BS-320): the goal, its month and where the countdown is.
        if let plan = thesis.exitPlan {
            let title = plan.targetText.map { "\(plan.goal.title) · \($0)" } ?? plan.goal.title
            let selling: Bool
            if case .selling = plan.phase() { selling = true } else { selling = false }
            rowsStack.addArrangedSubview(row(symbol: plan.goal.symbolName, tint: .secondaryLabel,
                                             text: attributed("Exit plan: " + title, detail: plan.countdown,
                                                              detailColor: selling ? .label : .secondaryLabel)))
        }

        //Check-ins, newest first.
        if !thesis.history.isEmpty {
            rowsStack.addArrangedSubview(label("Check-ins", style: .footnote, color: .secondaryLabel))
            for record in thesis.history.suffix(Self.historyShown).reversed() {
                let detail = record.summary.isEmpty ? StockHealthFormat.day(record.date)
                                                    : "\(StockHealthFormat.day(record.date)) · \(record.summary)"
                rowsStack.addArrangedSubview(row(symbol: Self.symbol(for: record.answer), tint: .secondaryLabel,
                                                 text: attributed(record.answer.shortTitle, detail: detail, detailColor: .secondaryLabel)))
            }
        }
    }

    private static func symbol(for answer: CheckInAnswer) -> String {
        switch answer {
        case .intact: return "checkmark.seal"
        case .changed: return "arrow.triangle.2.circlepath"
        case .unsure: return "clock"
        }
    }

    ///"Check-in waiting: 11% below your start", with the button that opens the sheet.
    private func checkInBanner(_ checkIn: CheckIn) -> UIView {
        let color = StockHealthFormat.color(for: .attention)
        let summary = checkIn.conditions.map(\.summary).joined(separator: ", ")
        let text = attributed(checkIn.reminder ? "Reminder: check in" : "Check-in waiting", detail: summary, detailColor: color)
        let banner = row(symbol: "exclamationmark.triangle.fill", tint: color, text: text)
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Check In"
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = color
        configuration.baseBackgroundColor = color
        let button = UIButton(configuration: configuration)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addAction(UIAction { [weak self] _ in self?.onCheckIn?() }, for: .touchUpInside)
        let line = UIStackView(arrangedSubviews: [banner, button])
        line.spacing = 8
        line.alignment = .center
        return line
    }

    // MARK: - Conditions

    private func conditionRows(_ thesis: Thesis, health: StockHealth?, startPrice: Double?) -> [UIView] {
        var rows: [UIView] = []
        let met = StockHealthFormat.color(for: .attention)

        if thesis.reconsiderOnTrendBreak {
            let detail: String
            var isMet = false
            if let health {
                if let date = health.sinceStart?.trendBreak {
                    detail = "Happened \(StockHealthFormat.day(date))"
                    isMet = true
                } else if health.trend.state == .downtrend {
                    detail = "Already in a trend break when you started"
                } else {
                    detail = "Not since you started"
                }
            } else {
                detail = "—"
            }
            rows.append(conditionRow("Trend break", detail: detail, isMet: isMet, color: met))
        }
        if let drop = thesis.reconsiderBelowStart {
            var detail = "—"
            var isMet = false
            if let health, let startPrice, startPrice > 0 {
                let change = health.close / startPrice - 1
                isMet = change <= -drop
                detail = isMet ? "Met: now \(StockHealthFormat.percent(change)) from your start"
                               : "Now \(StockHealthFormat.percent(change)) from your start"
            }
            rows.append(conditionRow("\(StockHealthFormat.unsignedPercent(drop, digits: 0)) below my starting price",
                                     detail: detail, isMet: isMet, color: met))
        }
        if let drop = thesis.reconsiderBelowHigh {
            var detail = "—"
            var isMet = false
            if let health, let high = health.sinceStart?.high, high.value > 0 {
                let change = health.close / high.value - 1
                isMet = change <= -drop
                detail = isMet ? "Met: now \(StockHealthFormat.percent(change)) from the high since"
                               : "Now \(StockHealthFormat.percent(change)) from the high since"
            }
            rows.append(conditionRow("\(StockHealthFormat.unsignedPercent(drop, digits: 0)) below its high since I started",
                                     detail: detail, isMet: isMet, color: met))
        }
        return rows
    }

    private func conditionRow(_ title: String, detail: String, isMet: Bool, color: UIColor) -> UIView {
        let view = row(symbol: isMet ? "exclamationmark.triangle.fill" : "circle",
                       tint: isMet ? color : .tertiaryLabel,
                       text: attributed(title, detail: detail, detailColor: isMet ? color : .secondaryLabel))
        view.accessibilityLabel = "\(title). \(detail)"
        return view
    }

    // MARK: - Building blocks

    private func clear() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    private func attributed(_ title: String, detail: String, detailColor: UIColor) -> NSAttributedString {
        let text = NSMutableAttributedString(string: title,
                                             attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.label])
        text.append(NSAttributedString(string: "\n" + detail,
                                       attributes: [.font: UIFont.preferredFont(forTextStyle: .footnote), .foregroundColor: detailColor]))
        return text
    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func row(symbol: String, tint: UIColor, text: NSAttributedString) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = tint
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        let label = UILabel()
        label.attributedText = text
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.spacing = 10
        stack.alignment = .firstBaseline
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = text.string.replacingOccurrences(of: "\n", with: ". ")
        return stack
    }
}
