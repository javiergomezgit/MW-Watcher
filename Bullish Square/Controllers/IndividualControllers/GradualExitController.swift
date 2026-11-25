//
//  GradualExitController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import UIKit

///"Why sell gradually?" (BS-320): the SPY example from the Calm Investing research, behind the
///exit plan's "start selling gradually N months before". Past prices with their sample and
///dates, as every claim shown to users must have (spec §2); never a promise.
final class GradualExitController: UIViewController {

    ///From the research (Nov 2017 to Nov 2026, SPY, split-adjusted, no dividends): $100,000
    ///needed on one date, sold that day versus in 12 equal monthly pieces (spec §2,
    ///CALM_INVESTING_PROMPT §2.3). Worded no more precisely than the research records it.
    private static let paragraphs: [(title: String?, body: String)] = [
        (nil, "When money is needed on a date, selling everything on one day is a bet on that day's price."),
        ("Sold on one day",
         "$100,000 of SPY needed on a single day between Nov 2017 and Nov 2026 would have fetched anywhere from "
            + "$86,398 (sold 23 Mar 2020, in the COVID fall) to $147,567 (sold 31 Dec 2021)."),
        ("Sold in 12 monthly pieces",
         "Selling the same $100,000 in 12 equal monthly pieces instead narrowed the range to "
            + "$115,363 to $132,682."),
        ("Why it helps",
         "Gradual selling never catches the best day, and it almost never gets caught on the worst. "
            + "That's why the plan starts selling a set number of months before the goal, 12 by default."),
        ("What this is",
         "Past prices of one fund over one period, split-adjusted and without dividends. Not a prediction "
            + "and not advice. The app reminds you of your own plan; it never sells anything.")
    ]

    func embedded() -> UINavigationController {
        let navigation = UINavigationController(rootViewController: self)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Why Sell Gradually?"
        view.backgroundColor = UIColor(named: "colorPrimary")
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])

        for paragraph in Self.paragraphs {
            if let title = paragraph.title {
                let heading = UILabel()
                heading.text = title
                heading.font = UIFont.preferredFont(forTextStyle: .headline)
                heading.adjustsFontForContentSizeCategory = true
                heading.accessibilityTraits = .header
                stack.addArrangedSubview(heading)
                stack.setCustomSpacing(4, after: heading)
            }
            let body = UILabel()
            body.text = paragraph.body
            body.font = UIFont.preferredFont(forTextStyle: .body)
            body.adjustsFontForContentSizeCategory = true
            body.textColor = paragraph.title == "What this is" ? .secondaryLabel : .label
            body.numberOfLines = 0
            stack.addArrangedSubview(body)
        }
    }
}
