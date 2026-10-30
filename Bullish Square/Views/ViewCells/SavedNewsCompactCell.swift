//
//  SavedNewsCompactCell.swift
//  Bullish Square
//
//  Created by Javier Gomez on 10/30/26.
//

import UIKit

///One saved story as a reading-list row: thumbnail on the left, source and date, the
///headline, and a share button. Styled like the News tab's cards - same card colour, fonts and
///accents - but compact, so a long saved list is easy to scan.
///
///Built in code. It replaced the storyboard prototype that carried the ElevenLabs "read
///aloud" button.
final class SavedNewsCompactCell: UITableViewCell {

    static let reuseIdentifier = "SavedNewsCompactCell"

    ///Thumbnail side, in points. Pictures are decoded at this size, not their saved size.
    static let thumbnailSide: CGFloat = 84

    let thumbnailView = UIImageView()
    let sourceLabel = UILabel()
    let dateLabel = UILabel()
    let headlineLabel = UILabel()
    let shareButton = UIButton(type: .system)

    private let card = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
    }

    func configure(headline: String, source: String, date: String, thumbnail: UIImage?) {
        headlineLabel.text = headline
        sourceLabel.text = source.isEmpty ? "News" : source
        dateLabel.text = date
        thumbnailView.image = thumbnail ?? UIImage(named: "mw-logo")
        accessibilityLabel = "\(headline). \(source), \(date)"
    }

    ///Dims the card while pressed, as a tap opens the story.
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: animated ? 0.15 : 0) {
            self.card.alpha = highlighted ? 0.7 : 1
        }
    }

    // MARK: - Layout

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        isAccessibilityElement = true
        accessibilityTraits = .button

        //The News tab card's colour, from NewsTab.storyboard.
        card.backgroundColor = UIColor(red: 0.125, green: 0.161, blue: 0.239, alpha: 1)
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 10
        thumbnailView.backgroundColor = UIColor(named: "colorPrimary")

        sourceLabel.font = UIFont(name: "KohinoorGujarati-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        sourceLabel.textColor = UIColor(named: "AccentColor")
        sourceLabel.setContentHuggingPriority(.required, for: .horizontal)
        sourceLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        dateLabel.font = UIFont(name: "KohinoorGujarati-Regular", size: 11) ?? .systemFont(ofSize: 11)
        dateLabel.textColor = UIColor(named: "colorSecondary")
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        headlineLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        headlineLabel.textColor = UIColor(named: "colorSecondary")
        headlineLabel.numberOfLines = 3
        headlineLabel.lineBreakMode = .byTruncatingTail

        let symbol = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: symbol), for: .normal)
        shareButton.tintColor = UIColor(named: "colorAccent")
        shareButton.accessibilityLabel = "Share"

        let sourceRow = UIStackView(arrangedSubviews: [sourceLabel, dateLabel])
        sourceRow.axis = .horizontal
        sourceRow.spacing = 6
        sourceRow.alignment = .firstBaseline

        let textColumn = UIStackView(arrangedSubviews: [sourceRow, headlineLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 4
        textColumn.alignment = .fill

        contentView.addSubview(card)
        [thumbnailView, textColumn, shareButton].forEach(card.addSubview)
        [card, thumbnailView, textColumn, shareButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let side = Self.thumbnailSide
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            thumbnailView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            thumbnailView.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            thumbnailView.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10),
            thumbnailView.widthAnchor.constraint(equalToConstant: side),
            thumbnailView.heightAnchor.constraint(equalToConstant: side),

            textColumn.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            textColumn.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            textColumn.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10),
            textColumn.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -4),

            shareButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            shareButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}
