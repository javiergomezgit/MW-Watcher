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
    ///The reader hid or showed the answer with the chevron, or a pill showed it again.
    var onCollapseChange: ((Bool) -> Void)?

    ///Gives the card the chevron that hides its answer and keeps the pills. Off for Ask AI's
    ///card, which goes away by itself when the question does.
    var isCollapsible = false {
        didSet { updatePillsRow() }
    }
    ///Only the pills and the chevron show. Set by the screen, which remembers it.
    var isCollapsed = false {
        didSet { applyCollapse() }
    }
    private var labelCount = 0

    private let card = UIView()
    private let pillsStack = UIStackView()
    ///Holds the pills, so on a narrow phone they scroll sideways instead of squeezing until
    ///"Why markets moved" wrapped onto two lines.
    private let pillsScroll = UIScrollView()
    private let pillsRow = UIStackView()
    private let collapseButton = UIButton(type: .system)
    private let titleRow = UIStackView()
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
        updateSourcesButton()
        applyCollapse()
    }

    ///The pills above the title, one per answer the card switches between, `selected` lit.
    ///Fewer than two labels hide the row: there is nothing to switch to. (BS-250)
    func setOptions(_ labels: [String], selected: Int) {
        pillsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, label) in labels.enumerated() {
            pillsStack.addArrangedSubview(pill(label, index: index, isSelected: index == selected))
        }
        labelCount = labels.count
        updatePillsRow()
    }

    ///With the chevron the row shows even for one answer, so the card can still be hidden.
    private func updatePillsRow() {
        pillsScroll.isHidden = labelCount < 2
        collapseButton.isHidden = !isCollapsible
        pillsRow.isHidden = labelCount < 2 && !isCollapsible
    }

    ///Hidden, the card is its pills and the chevron: the answer, sources and note go.
    private func applyCollapse() {
        let hidden = isCollapsible && isCollapsed
        titleRow.isHidden = hidden
        linesStack.isHidden = hidden
        sourcesButton.isHidden = hidden || storyCount == 0
        noteLabel.isHidden = hidden
        if hidden {
            sourcesStack.isHidden = true
            updateSourcesButton()
        }
        let symbol = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        collapseButton.setImage(UIImage(systemName: hidden ? "chevron.down" : "chevron.up", withConfiguration: symbol), for: .normal)
        collapseButton.accessibilityLabel = hidden ? "Show summary" : "Hide summary"
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard collapsed != isCollapsed else { return }
        isCollapsed = collapsed
        onCollapseChange?(collapsed)
        onSizeChange?()
    }

    private func pill(_ label: String, index: Int, isSelected: Bool) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = label
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        //Always one line, at its full width; the row scrolls when they don't all fit.
        configuration.titleLineBreakMode = .byClipping
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
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.titleLabel?.numberOfLines = 1
        button.accessibilityTraits.insert(isSelected ? .selected : [])
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            //A pill on a hidden card is a wish to read it.
            self.setCollapsed(false)
            guard !isSelected else { return }
            self.onSelectOption?(index)
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

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(updatedLabel)
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
        //Like the Sources toggle, in the accent colour; a wider target than the chevron.
        collapseButton.tintColor = UIColor(named: "AccentColor")
        collapseButton.contentHorizontalAlignment = .trailing
        collapseButton.isHidden = true
        collapseButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.setCollapsed(!self.isCollapsed)
        }, for: .touchUpInside)
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collapseButton.widthAnchor.constraint(equalToConstant: 44),
            collapseButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        pillsScroll.showsHorizontalScrollIndicator = false
        pillsScroll.alwaysBounceHorizontal = false
        pillsStack.translatesAutoresizingMaskIntoConstraints = false
        pillsScroll.addSubview(pillsStack)
        //As wide as the pills when they fit, so the chevron stays at the trailing edge;
        //narrower than them when they don't, and then it scrolls.
        let hugPills = pillsScroll.widthAnchor.constraint(equalTo: pillsStack.widthAnchor)
        hugPills.priority = .defaultHigh
        NSLayoutConstraint.activate([
            pillsStack.topAnchor.constraint(equalTo: pillsScroll.contentLayoutGuide.topAnchor),
            pillsStack.bottomAnchor.constraint(equalTo: pillsScroll.contentLayoutGuide.bottomAnchor),
            pillsStack.leadingAnchor.constraint(equalTo: pillsScroll.contentLayoutGuide.leadingAnchor),
            pillsStack.trailingAnchor.constraint(equalTo: pillsScroll.contentLayoutGuide.trailingAnchor),
            pillsScroll.heightAnchor.constraint(equalTo: pillsStack.heightAnchor),
            hugPills
        ])
        pillsRow.addArrangedSubview(pillsScroll)
        pillsRow.addArrangedSubview(rest)
        pillsRow.addArrangedSubview(collapseButton)
        pillsRow.axis = .horizontal
        pillsRow.alignment = .center
        pillsRow.isHidden = true
        applyCollapse()

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
