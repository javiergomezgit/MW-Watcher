//
//  MarketBriefCardView.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/2/26.
//

import UIKit

///"Why markets moved" at the top of Markets (BS-242): the server's few cited lines, the stories
///they cite behind a Sources toggle, and a note that it is an AI summary and not advice. Ask AI
///answers use the same card (BS-243), and on Markets and Economy pills switch it between
///answers written ahead (BS-250).
///
///Built in code and styled like the News cards. It carries the gap to the first story below it,
///so the list header is just the search field and this.
final class MarketBriefCardView: UIView {

    ///A cited story was tapped.
    var onOpenStory: ((URL) -> Void)?
    ///Sources were shown or hidden; the list header has to change height.
    var onSizeChange: (() -> Void)?
    ///A pill was tapped: its index in the labels last given to `setOptions`. (BS-250)
    var onSelectOption: ((Int) -> Void)?

    private let card = UIView()
    private let pillsStack = UIStackView()
    private let pillsRow = UIStackView()
    private let titleLabel = UILabel()
    private let updatedLabel = UILabel()
    private let linesStack = UIStackView()
    private let sourcesButton = UIButton(type: .system)
    private let sourcesStack = UIStackView()
    private let noteLabel = UILabel()
    private var storyCount = 0

    ///Gap from the card to the first story, as between the search field and a story.
    static let bottomGap: CGFloat = 16
    private let bottomGap: CGFloat

    ///`bottomGap` 0 when what holds the card already leaves the gap, as Ask AI's row does.
    init(bottomGap: CGFloat = MarketBriefCardView.bottomGap) {
        self.bottomGap = bottomGap
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        bottomGap = Self.bottomGap
        super.init(coder: coder)
        setupViews()
    }

    ///A brief, an answer written ahead, or an Ask AI answer (BS-243). With no stories there is
    ///no Sources toggle.
    func configure(title: String, subtitle: String, note: String, lines: [MarketBrief.Line], stories: [MarketBrief.Story]) {
        titleLabel.text = title
        updatedLabel.text = subtitle
        noteLabel.text = note

        linesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in lines {
            let label = UILabel()
            label.numberOfLines = 0
            label.attributedText = Self.lineText(line)
            linesStack.addArrangedSubview(label)
        }

        sourcesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, story) in stories.enumerated() {
            sourcesStack.addArrangedSubview(sourceRow(number: index + 1, story: story))
        }
        storyCount = stories.count
        sourcesStack.isHidden = true
        sourcesButton.isHidden = stories.isEmpty
        updateSourcesButton()
    }

    ///The pills above the title, one per answer the card switches between, `selected` lit.
    ///Fewer than two labels hide the row: there is nothing to switch to. (BS-250)
    func setOptions(_ labels: [String], selected: Int) {
        pillsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, label) in labels.enumerated() {
            pillsStack.addArrangedSubview(pill(label, index: index, isSelected: index == selected))
        }
        pillsRow.isHidden = labels.count < 2
    }

    private func pill(_ label: String, index: Int, isSelected: Bool) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = label
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.baseBackgroundColor = isSelected
            ? UIColor(named: "AccentColor")
            : UIColor(named: "colorSecondary")?.withAlphaComponent(0.1)
        configuration.baseForegroundColor = isSelected ? card.backgroundColor : UIColor(named: "colorSecondary")
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont(name: "Avenir-Heavy", size: 13) ?? .boldSystemFont(ofSize: 13)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityTraits.insert(isSelected ? .selected : [])
        button.addAction(UIAction { [weak self] _ in
            guard !isSelected else { return }
            self?.onSelectOption?(index)
        }, for: .touchUpInside)
        return button
    }

    // MARK: - Content

    ///"Updated 9:00 AM" today, "Updated Fri 4:00 PM" before.
    static func updatedText(for date: Date, now: Date = Date()) -> String {
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return "Updated " + date.formatted(date: .omitted, time: .shortened)
        }
        return "Updated " + date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    ///"• Intel plunged on a weak outlook. [1][2]", the numbers in the accent colour.
    private static func lineText(_ line: MarketBrief.Line) -> NSAttributedString {
        let body = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        let small = UIFont(name: "Avenir-Heavy", size: 12) ?? .boldSystemFont(ofSize: 12)
        //A line citing nothing (an answer the stories do not cover) has no numbers after it.
        let text = NSMutableAttributedString(string: "• " + line.text + (line.sources.isEmpty ? "" : " "), attributes: [
            .font: body,
            .foregroundColor: UIColor(named: "colorSecondary") ?? .label
        ])
        text.append(NSAttributedString(string: line.sources.map { "[\($0)]" }.joined(), attributes: [
            .font: small,
            .foregroundColor: UIColor(named: "AccentColor") ?? .systemBlue
        ]))
        return text
    }

    ///"1  Intel plunges 29% on weak outlook · CNBC", opening the story when tapped.
    private func sourceRow(number: Int, story: MarketBrief.Story) -> UIView {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        configuration.titleAlignment = .leading
        let text = NSMutableAttributedString(string: "\(number)  ", attributes: [
            .font: UIFont(name: "Avenir-Heavy", size: 13) ?? .boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor(named: "AccentColor") ?? .systemBlue
        ])
        text.append(NSAttributedString(string: story.headline + " · " + story.source, attributes: [
            .font: UIFont(name: "Avenir-Book", size: 13) ?? .systemFont(ofSize: 13),
            .foregroundColor: UIColor(named: "colorSecondary") ?? .label
        ]))
        configuration.attributedTitle = AttributedString(text)

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.accessibilityLabel = "Source \(number): \(story.headline), \(story.source)"
        let link = story.link
        button.addAction(UIAction { [weak self] _ in
            guard let url = URL(string: link) else { return }
            self?.onOpenStory?(url)
        }, for: .touchUpInside)
        return button
    }

    private func updateSourcesButton() {
        let shown = !sourcesStack.isHidden
        let symbol = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        sourcesButton.setImage(UIImage(systemName: shown ? "chevron.up" : "chevron.down", withConfiguration: symbol), for: .normal)
        sourcesButton.setTitle("Sources (\(storyCount))", for: .normal)
        sourcesButton.accessibilityHint = shown ? "Hides the stories" : "Shows the stories this summary cites"
    }

    // MARK: - Layout

    private func setupViews() {
        backgroundColor = .clear

        //The News tab card's colour, from NewsTab.storyboard, as the saved-news rows use.
        card.backgroundColor = UIColor(red: 0.125, green: 0.161, blue: 0.239, alpha: 1)
        card.layer.cornerRadius = 12

        titleLabel.text = "Why markets moved"
        titleLabel.font = UIFont(name: "Avenir-Heavy", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = UIColor(named: "colorSecondary")
        //A card's question can be longer than the row (BS-250): the title wraps and the time
        //keeps its width.
        titleLabel.numberOfLines = 0
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        updatedLabel.font = UIFont(name: "Avenir-Book", size: 12) ?? .systemFont(ofSize: 12)
        updatedLabel.textColor = UIColor(named: "colorSecondary")?.withAlphaComponent(0.7)
        updatedLabel.textAlignment = .right
        updatedLabel.setContentHuggingPriority(.required, for: .horizontal)
        updatedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, updatedLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = 8

        linesStack.axis = .vertical
        linesStack.spacing = 6

        sourcesButton.tintColor = UIColor(named: "AccentColor")
        sourcesButton.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 13) ?? .boldSystemFont(ofSize: 13)
        sourcesButton.semanticContentAttribute = .forceRightToLeft
        sourcesButton.contentHorizontalAlignment = .leading
        sourcesButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.sourcesStack.isHidden.toggle()
            self.updateSourcesButton()
            self.onSizeChange?()
        }, for: .touchUpInside)

        sourcesStack.axis = .vertical
        sourcesStack.spacing = 2

        noteLabel.text = "AI summary of the stories it cites · Not financial advice"
        noteLabel.numberOfLines = 0
        noteLabel.font = UIFont(name: "Avenir-Book", size: 11) ?? .systemFont(ofSize: 11)
        noteLabel.textColor = UIColor(named: "colorSecondary")?.withAlphaComponent(0.6)

        pillsStack.axis = .horizontal
        pillsStack.spacing = 8
        //The pills keep their size at the leading edge; the empty view takes the rest.
        let rest = UIView()
        rest.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pillsRow.addArrangedSubview(pillsStack)
        pillsRow.addArrangedSubview(rest)
        pillsRow.axis = .horizontal
        pillsRow.isHidden = true

        let content = UIStackView(arrangedSubviews: [pillsRow, titleRow, linesStack, sourcesButton, sourcesStack, noteLabel])
        content.axis = .vertical
        content.spacing = 10
        content.alignment = .fill
        content.setCustomSpacing(4, after: sourcesButton)

        addSubview(card)
        card.addSubview(content)
        [card, content].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomGap),

            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
    }
}
