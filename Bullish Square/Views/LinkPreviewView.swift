//
//  LinkPreviewView.swift
//  Bullish Square
//

import UIKit

///The card under a post with a link: the page's picture on the left, its title and site on
///the right. (BS-289)
///
///Always the same height, so the row doesn't jump when the page's details arrive: the site
///shows at once, the title and picture fill in after.
final class LinkPreviewView: UIControl {

    // MARK: - Properties

    static let height: CGFloat = 84

    private let thumbnail = UIImageView()
    private let titleLabel = UILabel()
    private let siteLabel = UILabel()
    private(set) var url: URL?

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ProfileStyle.text.withAlphaComponent(0.06)
        layer.cornerRadius = 10
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .link

        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.tintColor = ProfileStyle.secondaryText
        thumbnail.backgroundColor = ProfileStyle.text.withAlphaComponent(0.06)

        titleLabel.font = UIFont(name: "Avenir-Heavy", size: 14) ?? .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = ProfileStyle.text
        titleLabel.numberOfLines = 2
        siteLabel.font = UIFont(name: "Avenir-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        siteLabel.textColor = ProfileStyle.secondaryText

        let texts = UIStackView(arrangedSubviews: [titleLabel, siteLabel])
        texts.axis = .vertical
        texts.spacing = 3
        let row = UIStackView(arrangedSubviews: [thumbnail, texts])
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: Self.height),
            thumbnail.heightAnchor.constraint(equalToConstant: Self.height)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    // MARK: - Content

    ///The site at once; the title and picture when `preview` has them.
    func show(_ url: URL, preview: LinkPreviewStore.Preview?) {
        self.url = url
        let site = LinkPreviewStore.site(of: url)
        siteLabel.text = site
        titleLabel.text = preview?.title ?? site
        if let image = preview?.image {
            thumbnail.image = image
            thumbnail.contentMode = .scaleAspectFill
        } else {
            thumbnail.image = UIImage(systemName: "link")
            thumbnail.contentMode = .center
        }
        accessibilityLabel = [preview?.title, site].compactMap { $0 }.joined(separator: ", ")
    }
}
