//
//  TabTitleRow.swift
//  Bullish Square
//

import UIKit

///A tab's large title and its buttons, in a row of its own at the top of the screen. (BS-251)
///
///The navigation bar kept an empty row above a large title, for a back button a tab's first
///screen never has, and iOS cannot shrink it. A tab hides its bar while it shows (`setBarHidden`)
///and installs this instead. The bar comes back for the screens the tab opens, which need their
///title and back button.
///
///Installed in the extra safe area it adds, so whatever the storyboard pins to the safe area
///starts under it.
final class TabTitleRow: UIStackView {

    ///Tall enough for the large title at its default size, as the bar's title row is.
    static let height: CGFloat = 52
    ///Space above the row, under the status bar: about half the bar's empty row, which was
    ///too much, while none at all crowded the title against the status bar.
    static let topGap: CGFloat = 20
    ///The buttons' size, as they had in the bar.
    static let buttonSize: CGFloat = 36

    private let titleLabel = UILabel()

    var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }

    ///`buttons` are shown at the trailing edge in the order given, each `buttonSize` square.
    init(title: String?, buttons: [UIView]) {
        super.init(frame: .zero)
        //The large title's font at its default size, so the tabs match the screens that keep
        //the system one. Fixed, as the row's height is; a long watchlist name shrinks instead.
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let rest = UIView()
        rest.setContentHuggingPriority(.defaultLow, for: .horizontal)

        axis = .horizontal
        alignment = .center
        spacing = 16
        addArrangedSubview(titleLabel)
        addArrangedSubview(rest)
        for button in buttons {
            addArrangedSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: Self.buttonSize),
                button.widthAnchor.constraint(equalTo: button.heightAnchor)
            ])
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    ///Adds the row to the top of `controller`'s view, on its layout margins, and moves the
    ///safe area down by the row's height and the gap above it.
    func install(in controller: UIViewController) {
        let view = controller.view!
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        controller.additionalSafeAreaInsets.top = Self.topGap + Self.height
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            heightAnchor.constraint(equalToConstant: Self.height)
        ])
    }

    ///Call from viewWillAppear with true and viewWillDisappear with false.
    static func setBarHidden(_ hidden: Bool, for controller: UIViewController, animated: Bool) {
        controller.navigationController?.setNavigationBarHidden(hidden, animated: animated)
    }
}
