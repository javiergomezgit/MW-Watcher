//
//  EmptyStateView.swift
//  Bullish Square
//

import UIKit

///What a screen says when it has nothing to show: what is missing and, where there is one,
///the step that fills it. A blank list read the same as one still loading or one that had
///failed. (BS-121)
///
///Set as a table's `backgroundView`, or pinned over a screen with no table to put it in.
final class EmptyStateView: UIView {

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?
    ///Pins the message below the top in `nearTop` mode; nil when centred.
    private var messageTopConstraint: NSLayoutConstraint?

    ///What covers the view's top, such as a navigation bar, for `nearTop` to clear. A table's
    ///`backgroundView` gets no safe area, so the message sat under the search bar; the screen
    ///passes its table's `adjustedContentInset.top` instead.
    var topInset: CGFloat = 0 {
        didSet { messageTopConstraint?.constant = topInset + 32 }
    }

    ///`nearTop` keeps the message above the keyboard on screens that open with it up; the
    ///default centres it a little above the middle.
    init(title: String, message: String, actionTitle: String? = nil, nearTop: Bool = false,
         action: (() -> Void)? = nil) {
        super.init(frame: .zero)
        setUp(nearTop: nearTop)
        configure(title: title, message: message, actionTitle: actionTitle, action: action)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    ///Replaces the text, for one view that says different things (a search with no matches,
    ///a search that failed). No `actionTitle` hides the button.
    func configure(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        titleLabel.text = title
        messageLabel.text = message
        actionButton.setTitle(actionTitle, for: .normal)
        actionButton.isHidden = actionTitle == nil
        self.action = action
    }

    // MARK: - Layout

    private func setUp(nearTop: Bool) {
        titleLabel.font = UIFont(name: "Avenir-Heavy", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = UIColor(named: "colorSecondary")
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        messageLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = UIColor(named: "colorSecondary")?.withAlphaComponent(0.7)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        actionButton.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 16) ?? .boldSystemFont(ofSize: 16)
        actionButton.tintColor = UIColor(named: "colorAccent")
        actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)

        //Fill rather than centre: a multi-line label in a centred stack gets no width to wrap to.
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, actionButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 6
        stack.setCustomSpacing(14, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let vertical = nearTop
            ? stack.topAnchor.constraint(equalTo: topAnchor, constant: topInset + 32)
            : stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40)
        if nearTop { messageTopConstraint = vertical }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            vertical
        ])
    }

    @objc private func didTapAction() {
        action?()
    }
}
