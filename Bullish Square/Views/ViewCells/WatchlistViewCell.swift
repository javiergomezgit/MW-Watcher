//
//  MyTickersViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit

class WatchlistViewCell: UITableViewCell {

    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var nameCompanyLabel: UILabel!
    @IBOutlet var currentPriceLabel: UILabel!
    @IBOutlet weak var openChartButton: UIButton!
    @IBOutlet weak var imageCompanyImageView: UIImageView!

    ///Today's change under the price: a tinted capsule with a slanted arrow at the end. Built
    ///in code because a label cannot pad its text or carry a trailing symbol. Display only;
    ///taps pass through to the chart button underneath.
    let changePill: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.cornerStyle = .capsule
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 3
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 7, bottom: 0, trailing: 7)
        let button = UIButton(configuration: configuration)
        button.isUserInteractionEnabled = false
        return button
    }()

    ///Built in code, so the storyboard prototype needs no change.
    let sparklineView = SparklineView()

    ///The analysts' consensus under the company name. A button of its own, layered over the
    ///row's full-size chart button, so a tap on this line opens the analyst sheet and a tap
    ///anywhere else still opens the chart.
    let analystTargetButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "target",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium))
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        configuration.titleLineBreakMode = .byTruncatingTail
        //Outlined as a pill so the line reads as something to tap. As plain text it looked
        //like part of the row, and a tap there was expected to open the chart. The colours
        //follow the consensus and are set in showAnalystTarget.
        configuration.cornerStyle = .capsule
        configuration.background.strokeWidth = 1
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.isHidden = true
        return button
    }()

    ///The storyboard row was 75pt and every label in it is placed as a fraction of the row's
    ///height. Those fractions are pinned to what they came to at 75pt, so the ticker, name,
    ///price and sparkline stay exactly where they were and the extra height is only the
    ///analyst line. The controller returns this from heightForRowAt.
    static let rowHeight: CGFloat = 86
    private static let storyboardRowHeight: CGFloat = 75

    ///Below this row width the company name would be squeezed to a few characters, so the
    ///row goes without a sparkline. iOS 15 still runs on the 320pt first-generation iPhone SE.
    static let minimumWidthForSparkline: CGFloat = 350
    
    private var namesEndBeforeSparkline: [NSLayoutConstraint] = []
    private var namesEndBeforePrices: [NSLayoutConstraint] = []
    private var showsSparkline: Bool?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        pinTopBlockToStoryboardHeight()
        installChangePill()
        installSparkline()
        installAnalystTarget()
    }

    ///The ticker label is the anchor for everything else in the top block: the price sits on
    ///its top and height, the name and the change hang below them. Only its height (a quarter
    ///of the row) and its centre (at a quarter of the row) scale with the row, so replacing
    ///those two with their 75pt values fixes the whole block in place.
    private func pinTopBlockToStoryboardHeight() {
        let proportional = contentView.constraints.filter { constraint in
            constraint.firstItem === tickerLabel &&
            constraint.secondItem === contentView &&
            (constraint.firstAttribute == .height || constraint.firstAttribute == .centerY)
        }
        guard proportional.count == 2 else {
            print("WatchlistViewCell expected 2 proportional ticker constraints, found \(proportional.count); layout left as the storyboard has it")
            return
        }
        let quarter = Self.storyboardRowHeight * 0.25
        NSLayoutConstraint.deactivate(proportional)
        NSLayoutConstraint.activate([
            tickerLabel.heightAnchor.constraint(equalToConstant: quarter),
            tickerLabel.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: quarter)
        ])
    }

    ///Right-aligned under the price, level with the company name. Never wider than the price
    ///column, so the sparkline and names can end at the price's leading edge.
    private func installChangePill() {
        changePill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(changePill)
        currentPriceLabel.backgroundColor = .clear
        currentPriceLabel.textColor = .white

        NSLayoutConstraint.activate([
            changePill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            changePill.topAnchor.constraint(equalTo: currentPriceLabel.bottomAnchor, constant: 6),
            changePill.heightAnchor.constraint(equalToConstant: 20),
            changePill.leadingAnchor.constraint(greaterThanOrEqualTo: currentPriceLabel.leadingAnchor)
        ])
    }

    private func installSparkline() {
        sparklineView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sparklineView)

        //The price column is the price label's width on both lines, so ending at its leading
        //edge clears the price and the change. Centred on where the middle of the 75pt row
        //was, level with the price column, not on the taller row's middle.
        NSLayoutConstraint.activate([
            sparklineView.trailingAnchor.constraint(equalTo: currentPriceLabel.leadingAnchor, constant: -8),
            sparklineView.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.storyboardRowHeight / 2),
            sparklineView.widthAnchor.constraint(equalToConstant: 70),
            sparklineView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        //The storyboard sizes the ticker and name labels as a fraction of the row's width,
        //with nothing holding their trailing edge. That width is released so each label ends
        //where the free space does, truncating a long name rather than running under the line.
        let labels: [UIView] = [tickerLabel, nameCompanyLabel]
        let widths = (contentView.constraints + tickerLabel.constraints + nameCompanyLabel.constraints).filter { constraint in
            labels.contains { label in
                (constraint.firstItem === label && constraint.firstAttribute == .width) ||
                (constraint.secondItem === label && constraint.secondAttribute == .width)
            }
        }
        if widths.count != labels.count {
            print("WatchlistViewCell expected \(labels.count) label width constraints, found \(widths.count)")
        }
        NSLayoutConstraint.deactivate(widths)
        
        namesEndBeforeSparkline = labels.map {
            $0.trailingAnchor.constraint(lessThanOrEqualTo: sparklineView.leadingAnchor, constant: -8)
        }
        namesEndBeforePrices = labels.map {
            $0.trailingAnchor.constraint(lessThanOrEqualTo: currentPriceLabel.leadingAnchor, constant: -8)
        }
    }

    ///Below the name and clear of everything else, so it gets the row's full width even on
    ///the narrowest phone, where the sparkline is left out.
    private func installAnalystTarget() {
        analystTargetButton.translatesAutoresizingMaskIntoConstraints = false
        //Added last, so it is above the full-row chart button and receives its own taps.
        contentView.addSubview(analystTargetButton)

        NSLayoutConstraint.activate([
            analystTargetButton.leadingAnchor.constraint(equalTo: nameCompanyLabel.leadingAnchor),
            analystTargetButton.topAnchor.constraint(equalTo: nameCompanyLabel.bottomAnchor, constant: 2),
            analystTargetButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -5),
            analystTargetButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    ///nil clears the line: still loading, no analyst coverage, or the request failed. The row
    ///height is fixed, so an empty line leaves a gap rather than making rows jump.
    ///`recommendationKey` is the consensus ("buy", "strong_sell"...), from `AnalystTarget.consensusKey`,
    ///and picks the colours.
    func showAnalystTarget(_ text: String?, recommendationKey: String? = nil) {
        guard let text else {
            analystTargetButton.isHidden = true
            analystTargetButton.configuration?.attributedTitle = nil
            analystTargetButton.accessibilityLabel = nil
            return
        }
        let colors = AnalystTargetFormat.ratingColors(for: recommendationKey)
        analystTargetButton.configuration?.baseForegroundColor = colors.text
        analystTargetButton.configuration?.background.backgroundColor = colors.fill
        analystTargetButton.configuration?.background.strokeColor = colors.stroke

        //The chevron is the usual sign that a tap leads somewhere.
        var title = AttributedString(text + "  ›")
        title.font = UIFont(name: "Avenir-Heavy", size: 12) ?? .boldSystemFont(ofSize: 12)
        analystTargetButton.configuration?.attributedTitle = title
        analystTargetButton.accessibilityLabel = "Analyst price target: " + text
        analystTargetButton.accessibilityHint = "Shows the analysts' full consensus"
        analystTargetButton.isHidden = false
    }

    ///Today's change in percent, or nil while the price has not arrived. The arrow and the red
    ///or mint tint carry the direction, so the number is shown without a sign.
    func showChange(percent: Double?) {
        guard let percent else {
            changePill.isHidden = true
            changePill.accessibilityLabel = nil
            return
        }
        let isDown = percent < 0
        let tint: UIColor
        let text: UIColor
        if isDown {
            tint = UIColor(named: "downtrend") ?? .systemRed
            //`downtrend` itself is too dark to read as small text on colorPrimary.
            text = UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1)
        } else {
            tint = UIColor(named: "uptrend") ?? .systemGreen
            text = tint
        }

        let magnitude = String(format: "%.2f%%", abs(percent))
        var title = AttributedString(magnitude)
        title.font = UIFont(name: "Avenir-Heavy", size: 13) ?? .boldSystemFont(ofSize: 13)
        changePill.configuration?.attributedTitle = title
        //arrow.up.right points 45 degrees up, arrow.down.right 135 degrees.
        changePill.configuration?.image = UIImage(systemName: isDown ? "arrow.down.right" : "arrow.up.right",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .heavy))
        changePill.configuration?.baseForegroundColor = text
        changePill.configuration?.background.backgroundColor = tint.withAlphaComponent(isDown ? 0.2 : 0.16)
        changePill.accessibilityLabel = (isDown ? "Down " : "Up ") + magnitude + " today"
        changePill.isHidden = false
    }

    override func layoutSubviews() {
        //Decided from the row's real width, which only exists at layout time; awakeFromNib
        //still sees the storyboard's. Only a change of answer touches the constraints.
        let shows = bounds.width >= Self.minimumWidthForSparkline
        if shows != showsSparkline {
            showsSparkline = shows
            sparklineView.isHidden = !shows
            NSLayoutConstraint.deactivate(shows ? namesEndBeforePrices : namesEndBeforeSparkline)
            NSLayoutConstraint.activate(shows ? namesEndBeforeSparkline : namesEndBeforePrices)
        }
        super.layoutSubviews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        sparklineView.reset()
        showChange(percent: nil)
        showAnalystTarget(nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        openChartButton.setTitle("", for: .normal)

    }

}
