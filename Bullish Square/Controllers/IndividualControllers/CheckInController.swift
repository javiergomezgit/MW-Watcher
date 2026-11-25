//
//  CheckInController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import UIKit

///The check-in (BS-319): one of the person's own "look again if" conditions was met. It states
///what happened with the price facts, reminds them why they watch the stock, and asks "Has the
///business changed, or just the price?" with three answers, each saved with the date.
///
///A question, never an instruction: nothing here says buy, sell or hold.
final class CheckInController: UIViewController {

    ///Hears the answer once it is saved; nil when closed without answering.
    var onFinish: ((CheckInAnswer?) -> Void)?

    private let thesis: Thesis
    private let checkIn: CheckIn
    private let priceText: (Double) -> String
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var answerButtons: [UIButton] = []
    private var finished = false

    init(thesis: Thesis, checkIn: CheckIn, priceText: @escaping (Double) -> String) {
        self.thesis = thesis
        self.checkIn = checkIn
        self.priceText = priceText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("CheckInController is built in code")
    }

    func embedded() -> UINavigationController {
        let navigation = UINavigationController(rootViewController: self)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Check In"
        view.backgroundColor = UIColor(named: "colorPrimary")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Later", style: .plain, target: self, action: #selector(laterTapped))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 18
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
        build()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { finish(nil) }
    }

    // MARK: - Content

    private func build() {
        let symbol = thesis.ticker.hasPrefix("^") ? String(thesis.ticker.dropFirst()) : thesis.ticker

        if checkIn.reminder {
            stack.addArrangedSubview(label("A week ago you weren't sure about \(symbol).", style: .subheadline, color: .secondaryLabel))
        }
        //What happened, one line per condition.
        for condition in checkIn.conditions {
            stack.addArrangedSubview(conditionRow(condition.sentence(symbol: symbol, priceText: priceText)))
        }
        stack.addArrangedSubview(label("Last close \(priceText(checkIn.close)) on \(StockHealthFormat.day(checkIn.asOf)).",
                                       style: .footnote, color: .secondaryLabel))

        //Why they watch it.
        var why = "You watch it for \(thesis.reason.title.lowercased())."
        if !thesis.note.isEmpty { why += "\n\u{201C}\(thesis.note)\u{201D}" }
        stack.addArrangedSubview(label(why, style: .body, color: .label))

        let question = label("Has the business changed, or just the price?", style: .title3, color: .label)
        question.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .bold))
        question.accessibilityTraits = .header
        stack.addArrangedSubview(question)

        let buttons = UIStackView()
        buttons.axis = .vertical
        buttons.spacing = 10
        for answer in CheckInAnswer.allCases {
            var configuration: UIButton.Configuration = answer == .unsure ? .gray() : .tinted()
            configuration.title = answer.title
            configuration.cornerStyle = .large
            configuration.buttonSize = .large
            let button = UIButton(configuration: configuration)
            button.addAction(UIAction { [weak self] _ in self?.answerTapped(answer) }, for: .touchUpInside)
            answerButtons.append(button)
            buttons.addArrangedSubview(button)
        }
        stack.addArrangedSubview(buttons)
        stack.addArrangedSubview(label("Your answer is saved on this thesis with today's date, as a note to yourself. Past prices, not advice.",
                                       style: .footnote, color: .secondaryLabel))
    }

    private func conditionRow(_ text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = StockHealthFormat.color(for: .attention)
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let text = label(text, style: .headline, color: .label)
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.spacing = 10
        row.alignment = .firstBaseline
        return row
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

    // MARK: - Actions

    private func finish(_ answer: CheckInAnswer?) {
        guard !finished else { return }
        finished = true
        onFinish?(answer)
    }

    @objc private func laterTapped() {
        finish(nil)
        dismiss(animated: true)
    }

    private func answerTapped(_ answer: CheckInAnswer) {
        answerButtons.forEach { $0.isEnabled = false }
        let summary = checkIn.conditions.map(\.summary).joined(separator: ", ")
        ThesisStore.shared.answer(thesis, with: answer, summary: summary) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.answerButtons.forEach { $0.isEnabled = true }
                Utilities.showAlert(on: self, title: "Can't Save", message: "Check your connection and try again.")
                return
            }
            self.finish(answer)
            self.dismiss(animated: true)
        }
    }
}

// MARK: - Words

extension CheckIn.Condition {

    ///How far under its reference the close is, as a positive fraction.
    private var drop: Double? {
        guard let reference, reference.value > 0 else { return nil }
        return 1 - close / reference.value
    }

    ///"NVDA closed 11% below where you started watching ($100.00 on 13 Nov 2026)."
    func sentence(symbol: String, priceText: (Double) -> String) -> String {
        switch kind {
        case .trendBreak:
            return "\(symbol) broke its long-term trend on \(StockHealthFormat.day(date))."
        case .belowStart:
            guard let drop, let reference else { return "\(symbol) closed below where you started watching." }
            return "\(symbol) closed \(StockHealthFormat.unsignedPercent(drop, digits: 0)) below where you started watching "
                + "(\(priceText(reference.value)) on \(StockHealthFormat.day(reference.date)))."
        case .belowHigh:
            guard let drop, let reference else { return "\(symbol) closed below its high since you started watching." }
            return "\(symbol) closed \(StockHealthFormat.unsignedPercent(drop, digits: 0)) below its high since you started watching "
                + "(\(priceText(reference.value)) on \(StockHealthFormat.day(reference.date)))."
        }
    }

    ///For the history: "Trend break", "11% below your start".
    var summary: String {
        switch kind {
        case .trendBreak: return "Trend break"
        case .belowStart: return drop.map { "\(StockHealthFormat.unsignedPercent($0, digits: 0)) below your start" } ?? "Below your start"
        case .belowHigh: return drop.map { "\(StockHealthFormat.unsignedPercent($0, digits: 0)) below the high since" } ?? "Below the high since"
        }
    }
}
