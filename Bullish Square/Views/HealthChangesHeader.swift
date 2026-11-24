//
//  HealthChangesHeader.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import UIKit

///The line above the watchlist that says whether anything changed since the last visit
///(BS-311): "✓ No change detected" most days, or "2 changes since you last looked" with the
///stocks named. The trend badges of the changed stocks carry a dot for the same visit.
///
///Display only. It describes past prices and never says what to do about them.
final class HealthChangesHeader: UIView {

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        detailLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("HealthChangesHeader is built in code")
    }

    ///Before any health has arrived for the list.
    func showChecking() {
        show(title: "Checking for changes…", titleColor: .secondaryLabel, detail: nil)
    }

    ///Health was asked for and didn't come: the provider is down or out of calls. Said plainly
    ///rather than "Checking…" forever; the next visit asks again.
    func showUnavailable() {
        show(title: "Changes can't be checked right now", titleColor: .secondaryLabel,
             detail: "Prices still update. Trends come back when the price service does.")
    }

    ///`changes` by ticker, in the list's order; `asOf` is the close the states describe.
    func show(changes: [(ticker: String, text: String)], isFirst: Bool, asOf: String?) {
        let closeLine = asOf.map { "As of \($0) close" }
        if changes.isEmpty {
            let title = isFirst ? "✓ Watching your stocks for changes" : "✓ No change detected"
            show(title: title, titleColor: .label, detail: closeLine)
            return
        }
        let count = changes.count
        let title = "\(count) change\(count == 1 ? "" : "s") since you last looked"
        let list = changes.map { "\($0.ticker) \($0.text)" }.joined(separator: " · ")
        show(title: title, titleColor: .label, detail: [list, closeLine].compactMap { $0 }.joined(separator: "\n"))
    }

    private func show(title: String, titleColor: UIColor, detail: String?) {
        titleLabel.text = title
        titleLabel.textColor = titleColor
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil
        accessibilityLabel = [title, detail].compactMap { $0 }.joined(separator: ". ")
    }

    ///The height for `width`, for the table's header frame.
    func fittingHeight(for width: CGFloat) -> CGFloat {
        systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                withHorizontalFittingPriority: .required,
                                verticalFittingPriority: .fittingSizeLevel).height
    }
}
