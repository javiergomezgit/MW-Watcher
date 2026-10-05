//
//  AnalystTargetController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/30/26.
//

import UIKit

// MARK: - Formatting

///Shared by the watchlist row and the sheet, so both show a target the same way.
enum AnalystTargetFormat {

    ///Whole dollars from $100 up, where cents are noise next to analysts' own rounding; cents
    ///below, where a $4.25 target rounded to $4 would be a 6% error.
    static func price(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        formatter.minimumFractionDigits = value >= 100 ? 0 : 2
        //The default is banker's rounding, which shows $1,234.50 as $1,234.
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    ///Always signed, so a target below today's price reads as clearly as one above it.
    static func percent(_ value: Double) -> String {
        //-0.04 would otherwise print as "-0.0%".
        let rounded = (value * 10).rounded() / 10
        return String(format: "%@%.1f%%", rounded > 0 ? "+" : (rounded < 0 ? "-" : ""), abs(rounded))
    }
}

// MARK: - Controller

///The sheet behind a watchlist row's analyst line: the average target and how far it is from
///today's price, the analysts' range, and the buy/hold/sell ratings.
///
///Reports a third-party consensus and nothing more. Colours stay neutral throughout - no green
///for upside or red for downside - because colour would read as the app itself telling the
///user to buy or sell.
final class AnalystTargetController: UIViewController {

    private let ticker: String
    private let companyName: String
    ///The price on the watchlist row, so the sheet and the row always agree. nil when the row
    ///has no price yet.
    private let currentPrice: Double?
    private let target: AnalystTarget
    private let fetchedAt: Date

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(ticker: String, companyName: String, currentPrice: Double?, target: AnalystTarget, fetchedAt: Date) {
        self.ticker = ticker
        self.companyName = companyName
        self.currentPrice = currentPrice
        self.target = target
        self.fetchedAt = fetchedAt
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("AnalystTargetController is built in code")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "colorPrimary")
        title = "Analyst Targets"
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
        stack.addArrangedSubview(targetSection())
        if let ratings = ratingsSection() {
            stack.addArrangedSubview(ratings)
        }
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

    private func targetSection() -> UIView {
        var rows: [UIView] = [Self.caption("AVERAGE PRICE TARGET")]

        rows.append(Self.label(AnalystTargetFormat.price(target.meanTarget), font: Self.heavy(34)))

        if let price = currentPrice, let upside = target.upsidePercent(from: price) {
            let direction = upside >= 0 ? "above" : "below"
            let text = "\(AnalystTargetFormat.percent(upside)) — \(direction) today's price of \(AnalystTargetFormat.price(price))"
            rows.append(Self.label(text, font: Self.medium(15)))
        }

        if let low = target.lowTarget, let high = target.highTarget, high > low {
            let range = AnalystRangeView(low: low, high: high, mean: target.meanTarget, price: currentPrice)
            rows.append(range)
            if let price = currentPrice, price < low || price > high {
                let side = price < low ? "below the lowest" : "above the highest"
                rows.append(Self.label("Today's price is \(side) analyst target.", font: Self.medium(13), color: Self.secondaryColor))
            }
        }

        if let count = target.analystCount, count > 0 {
            let noun = count == 1 ? "analyst's" : "analysts'"
            rows.append(Self.label("Based on \(count) \(noun) 12-month price targets.",
                                   font: Self.medium(13), color: Self.secondaryColor))
        }

        return Self.card(Self.column(rows, spacing: 8))
    }

    private func ratingsSection() -> UIView? {
        guard target.consensusLabel != nil || target.breakdown != nil else { return nil }
        var rows: [UIView] = [Self.caption("ANALYST RATINGS")]

        if let consensus = target.consensusLabel {
            rows.append(Self.label("Consensus: \(consensus)", font: Self.heavy(20)))
        }
        if let mean = target.recommendationMean {
            rows.append(Self.label(String(format: "%.1f on a scale from 1 (strong buy) to 5 (strong sell).", mean),
                                   font: Self.medium(13), color: Self.secondaryColor))
        }

        if let breakdown = target.breakdown {
            let counts = [breakdown.strongBuy, breakdown.buy, breakdown.hold, breakdown.sell, breakdown.strongSell]
            rows.append(AnalystBreakdownBar(counts: counts, colors: Self.ratingColors))
            for (index, name) in ["Strong Buy", "Buy", "Hold", "Sell", "Strong Sell"].enumerated() {
                rows.append(Self.legendRow(name: name, count: counts[index], color: Self.ratingColors[index]))
            }
            //Counted separately from the price targets above, and the two rarely match.
            let noun = breakdown.total == 1 ? "rating" : "ratings"
            rows.append(Self.label("\(breakdown.total) \(noun) this month.", font: Self.medium(13), color: Self.secondaryColor))
        }

        return Self.card(Self.column(rows, spacing: 8))
    }

    private func footerSection() -> UIView {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        let checked = relative.localizedString(for: fetchedAt, relativeTo: Date())

        let source = Self.label("Source: Yahoo Finance analyst consensus. Updated daily; last checked \(checked).",
                                font: Self.medium(12), color: Self.secondaryColor)
        //Interim wording until the legal copy in BS-103 is final.
        let disclaimer = Self.label("Analyst targets are third-party estimates, not a recommendation or investment advice.",
                                    font: Self.medium(12), color: Self.secondaryColor)
        return Self.column([source, disclaimer], spacing: 6)
    }

    // MARK: - Building blocks

    private static let secondaryColor = UIColor(named: "colorSecondary") ?? .secondaryLabel
    private static let accent = UIColor(named: "colorAccent") ?? .systemBlue

    ///Blues from bright to deep, strong buy to strong sell, with hold a neutral slate in the
    ///middle. Deliberately not the app's green and red, which would turn the breakdown into an
    ///instruction. Opaque and far apart in brightness: the earlier fades of one blue disappeared
    ///into the dark background at the sell end and could not be told apart.
    private static let ratingColors: [UIColor] = [
        UIColor(red: 0.56, green: 0.83, blue: 1.00, alpha: 1),   //Strong Buy
        UIColor(red: 0.29, green: 0.62, blue: 1.00, alpha: 1),   //Buy
        UIColor(red: 0.55, green: 0.61, blue: 0.71, alpha: 1),   //Hold
        UIColor(red: 0.21, green: 0.35, blue: 0.71, alpha: 1),   //Sell
        UIColor(red: 0.16, green: 0.22, blue: 0.50, alpha: 1)    //Strong Sell
    ]

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

    private static func legendRow(name: String, count: Int, color: UIColor) -> UIView {
        let swatch = UIView()
        swatch.backgroundColor = color
        swatch.layer.cornerRadius = 3
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 12),
            swatch.heightAnchor.constraint(equalToConstant: 12)
        ])

        let nameLabel = label(name, font: medium(15))
        let countLabel = label("\(count)", font: heavy(15))
        countLabel.textAlignment = .right
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [swatch, nameLabel, countLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }
}

// MARK: - Range bar

///low ——●——◎—— high: the analysts' range as a bar, today's price as a filled dot and the
///average target as a ring. When today's price is outside the range the scale widens to take
///it in, so the dot sits past the end of the bar instead of being pinned to it.
private final class AnalystRangeView: UIView {

    private let low: Double
    private let high: Double
    private let mean: Double
    private let price: Double?

    private let track = UIView()
    private let range = UIView()
    private let priceDot = UIView()
    private let meanRing = UIView()
    private let lowLabel = UILabel()
    private let highLabel = UILabel()
    private let legend = UILabel()

    private let barY: CGFloat = 12
    private let dotSize: CGFloat = 14

    init(low: Double, high: Double, mean: Double, price: Double?) {
        self.low = low
        self.high = high
        self.mean = mean
        self.price = price
        super.init(frame: .zero)

        let secondary = UIColor(named: "colorSecondary") ?? .secondaryLabel
        let accent = UIColor(named: "colorAccent") ?? .systemBlue
        let font = UIFont(name: "Avenir-Medium", size: 12) ?? .systemFont(ofSize: 12)

        track.backgroundColor = secondary.withAlphaComponent(0.25)
        range.backgroundColor = accent.withAlphaComponent(0.45)
        priceDot.backgroundColor = .label
        meanRing.layer.borderColor = accent.cgColor
        meanRing.layer.borderWidth = 3
        meanRing.backgroundColor = UIColor(named: "colorPrimary") ?? .systemBackground
        for bar in [track, range] { bar.layer.cornerRadius = 3 }
        for marker in [priceDot, meanRing] { marker.layer.cornerRadius = dotSize / 2 }

        lowLabel.text = "Low " + AnalystTargetFormat.price(low)
        highLabel.text = "High " + AnalystTargetFormat.price(high)
        var legendText = "◎ Average " + AnalystTargetFormat.price(mean)
        if let price {
            legendText = "● Today " + AnalystTargetFormat.price(price) + "     " + legendText
        }
        legend.text = legendText
        for label in [lowLabel, highLabel, legend] {
            label.font = font
            label.textColor = secondary
        }

        [track, range, meanRing, priceDot, lowLabel, highLabel, legend].forEach(addSubview)
        priceDot.isHidden = price == nil

        isAccessibilityElement = true
        accessibilityLabel = "Analyst targets range from \(AnalystTargetFormat.price(low)) to \(AnalystTargetFormat.price(high)), average \(AnalystTargetFormat.price(mean))"
            + (price.map { ". Today's price \(AnalystTargetFormat.price($0))" } ?? "")
    }

    required init?(coder: NSCoder) {
        fatalError("AnalystRangeView is built in code")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 64)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = dotSize / 2
        let width = bounds.width - inset * 2
        guard width > 0 else { return }

        let minimum = min(low, price ?? low)
        let maximum = max(high, price ?? high)
        let span = maximum - minimum
        func x(_ value: Double) -> CGFloat {
            guard span > 0 else { return inset + width / 2 }
            return inset + CGFloat((value - minimum) / span) * width
        }

        track.frame = CGRect(x: inset, y: barY - 3, width: width, height: 6)
        range.frame = CGRect(x: x(low), y: barY - 3, width: x(high) - x(low), height: 6)
        meanRing.frame = CGRect(x: x(mean) - inset, y: barY - inset, width: dotSize, height: dotSize)
        if let price {
            priceDot.frame = CGRect(x: x(price) - inset, y: barY - inset, width: dotSize, height: dotSize)
        }

        //Each end label sits under its end of the analysts' range, kept on screen.
        lowLabel.sizeToFit()
        highLabel.sizeToFit()
        let labelY = barY + dotSize
        lowLabel.frame.origin = CGPoint(x: max(0, min(x(low) - lowLabel.bounds.width / 2, bounds.width - lowLabel.bounds.width)), y: labelY)
        var highX = min(bounds.width - highLabel.bounds.width, max(0, x(high) - highLabel.bounds.width / 2))
        highX = max(highX, lowLabel.frame.maxX + 8)
        highLabel.frame.origin = CGPoint(x: highX, y: labelY)

        legend.frame = CGRect(x: 0, y: labelY + 20, width: bounds.width, height: 18)
    }
}

// MARK: - Ratings bar

///One bar split in proportion to the ratings, strong buy on the left.
private final class AnalystBreakdownBar: UIView {

    private let counts: [Int]
    private let segments: [UIView]

    init(counts: [Int], colors: [UIColor]) {
        self.counts = counts
        self.segments = colors.map { color in
            let segment = UIView()
            segment.backgroundColor = color
            return segment
        }
        super.init(frame: .zero)
        layer.cornerRadius = 5
        clipsToBounds = true
        segments.forEach(addSubview)
        //The legend rows below carry the numbers for VoiceOver.
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("AnalystBreakdownBar is built in code")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 12)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let total = counts.reduce(0, +)
        guard total > 0 else { return }
        //A thin gap between neighbours, so two similar blues side by side still read as two.
        let gap: CGFloat = 2
        let shown = counts.filter { $0 > 0 }.count
        let available = bounds.width - gap * CGFloat(max(shown - 1, 0))
        var x: CGFloat = 0
        for (segment, count) in zip(segments, counts) {
            guard count > 0 else {
                segment.frame = .zero
                continue
            }
            let width = available * CGFloat(count) / CGFloat(total)
            segment.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
            x += width + gap
        }
    }
}
