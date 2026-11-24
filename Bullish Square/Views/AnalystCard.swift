//
//  AnalystCard.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///The Analysts card under Key stats on a stock's chart screen (BS-309): the consensus word in
///its rating colour, the average target and how far it is from today's price, and how many
///analysts that is. A tap opens the full sheet (`AnalystTargetController`).
///
///The watchlist row keeps its own one-line pill; this is the same consensus with room to read
///it, for stocks opened from anywhere (search, Community, Markets). It reports a third-party
///consensus and nothing more: only the rating word is coloured, never the upside, so it can't
///read as the app saying buy or sell.
final class AnalystCard: UIView {

    ///Set by the chart screen; the card only says it was tapped.
    var onTap: (() -> Void)?

    private let consensusLabel = UILabel()
    private let targetLabel = UILabel()
    private let countLabel = UILabel()
    private let card = UIView()

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
        heading.text = "Analysts"
        heading.font = UIFont.preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .label

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous

        consensusLabel.font = UIFontMetrics(forTextStyle: .title3)
            .scaledFont(for: UIFont.systemFont(ofSize: 20, weight: .bold))
        consensusLabel.adjustsFontForContentSizeCategory = true

        let base = UIFont.preferredFont(forTextStyle: .subheadline)
        targetLabel.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .regular))
        targetLabel.adjustsFontForContentSizeCategory = true
        targetLabel.textColor = .label
        targetLabel.numberOfLines = 0

        countLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .secondaryLabel

        //The usual sign that a tap leads somewhere.
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [consensusLabel, targetLabel, countLabel])
        text.axis = .vertical
        text.spacing = 4

        let row = UIStackView(arrangedSubviews: [text, chevron])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
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

        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        card.isAccessibilityElement = true
        card.accessibilityTraits = .button
        card.accessibilityHint = "Shows the analysts' full consensus"
    }

    @objc private func tapped() {
        onTap?()
    }

    ///Briefly dims the card under the finger, like a table row, so the tap is felt.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        card.alpha = 0.6
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.2) { self.card.alpha = 1 }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.2) { self.card.alpha = 1 }
    }

    ///`price` is the price in the screen's header, so the card and the header never disagree.
    ///nil while it is unknown: the upside is left out rather than guessed.
    func update(_ target: AnalystTarget, price: Double?) {
        if let consensus = target.consensusLabel {
            consensusLabel.text = consensus
            consensusLabel.textColor = AnalystTargetFormat.ratingColor(for: target.consensusKey)
        } else {
            consensusLabel.text = "No consensus"
            consensusLabel.textColor = .secondaryLabel
        }

        var line = "Average target " + AnalystTargetFormat.price(target.meanTarget)
        if let price, let upside = target.upsidePercent(from: price) {
            line += " · " + AnalystTargetFormat.percent(upside) + " from today"
        }
        targetLabel.text = line

        if let count = target.analystCount, count > 0 {
            countLabel.text = "From \(count) \(count == 1 ? "analyst" : "analysts")"
            countLabel.isHidden = false
        } else {
            countLabel.text = nil
            countLabel.isHidden = true
        }

        card.accessibilityLabel = ["Analysts", consensusLabel.text, line, countLabel.text]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}
