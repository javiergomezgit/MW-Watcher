//
//  PostCell.swift
//  Bullish Square
//

import UIKit

///One post in a Community feed: who and when, the text with tappable $tickers, up to four
///photos, and like and reshare counts. A reshare shows "@x reshared" above the original.
///Built in code; the controller owns what the buttons do. (BS-266)
final class PostCell: UITableViewCell, UITextViewDelegate {

    static let reuseIdentifier = "PostCell"

    // MARK: - Callbacks

    var onAuthor: (() -> Void)?
    var onMore: (() -> Void)?
    var onLike: (() -> Void)?
    var onReshare: (() -> Void)?
    var onTicker: ((String) -> Void)?
    ///A photo was tapped: the post's photo URLs and which one.
    var onPhoto: (([String], Int) -> Void)?

    // MARK: - Views

    private let card = UIView()
    private let reshareLabel = UILabel()
    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let moreButton = UIButton(type: .system)
    private let textView = UITextView()
    private let gallery = UIStackView()
    private let likeButton = UIButton(type: .system)
    private let reshareButton = UIButton(type: .system)
    private var imageURLs: [String] = []
    ///The post this cell shows now, so a late avatar or photo for a reused cell is dropped.
    private var postId: String?

    private static let galleryHeight: CGFloat = 220

    // MARK: - Setup

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        card.backgroundColor = ProfileStyle.card
        card.layer.cornerRadius = 14
        card.clipsToBounds = true

        reshareLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        reshareLabel.textColor = ProfileStyle.secondaryText

        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 20
        avatar.tintColor = ProfileStyle.secondaryText
        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        nameLabel.font = UIFont(name: "Avenir-Heavy", size: 16) ?? .systemFont(ofSize: 16, weight: .heavy)
        nameLabel.textColor = .label
        metaLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        metaLabel.textColor = ProfileStyle.secondaryText
        let names = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        names.axis = .vertical
        names.spacing = 1
        names.isUserInteractionEnabled = true
        names.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = ProfileStyle.secondaryText
        moreButton.accessibilityLabel = "More"
        moreButton.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [avatar, names, moreButton])
        header.alignment = .center
        header.spacing = 10

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.linkTextAttributes = [.foregroundColor: UIColor(named: "uptrend") ?? ProfileStyle.accent]

        gallery.axis = .vertical
        gallery.spacing = 2
        gallery.layer.cornerRadius = 10
        gallery.clipsToBounds = true

        for (button, symbol, label) in [(likeButton, "heart", "Like"), (reshareButton, "arrow.2.squarepath", "Reshare")] {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: symbol)
            config.imagePadding = 6
            config.baseForegroundColor = ProfileStyle.secondaryText
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 12)
            button.configuration = config
            button.accessibilityLabel = label
        }
        likeButton.addAction(UIAction { [weak self] _ in self?.onLike?() }, for: .touchUpInside)
        reshareButton.addAction(UIAction { [weak self] _ in self?.onReshare?() }, for: .touchUpInside)
        let footer = UIStackView(arrangedSubviews: [likeButton, reshareButton, UIView()])
        footer.spacing = 16

        let stack = UIStackView(arrangedSubviews: [reshareLabel, header, textView, gallery, footer])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            moreButton.widthAnchor.constraint(equalToConstant: 32),
            gallery.heightAnchor.constraint(equalToConstant: Self.galleryHeight)
        ])
    }

    // MARK: - Content

    ///`shown` is the post whose content appears: the original for a reshare. `resharedBy` is
    ///the uid of who reshared it, nil for an ordinary post. `original` nil on a reshare means
    ///the original was deleted.
    func configure(shown: Post?, resharedBy: String?, liked: Bool, reshared: Bool, isOwn: Bool) {
        postId = shown?.id
        if let resharedBy {
            reshareLabel.text = "↻ \(AuthorDirectory.shared.handle(resharedBy)) reshared"
            reshareLabel.isHidden = false
        } else {
            reshareLabel.isHidden = true
        }

        guard let post = shown else {
            nameLabel.text = "Post unavailable"
            metaLabel.text = "The original was deleted."
            avatar.image = UIImage(systemName: "person.crop.circle.fill")
            textView.attributedText = nil
            textView.isHidden = true
            gallery.isHidden = true
            likeButton.isHidden = true
            reshareButton.isHidden = true
            return
        }
        likeButton.isHidden = false
        reshareButton.isHidden = false

        let directory = AuthorDirectory.shared
        //The @username is who posted; the name stays on their profile.
        nameLabel.text = directory.handle(post.authorUid)
        if directory.isAutomated(post.authorUid) {
            let meta = ProfileStyle.automatedBadge(font: metaLabel.font)
            meta.append(NSAttributedString(string: " · \(Self.age(of: post.createdAt))",
                                           attributes: [.font: metaLabel.font as Any, .foregroundColor: ProfileStyle.secondaryText]))
            metaLabel.attributedText = meta
        } else {
            metaLabel.text = Self.age(of: post.createdAt)
        }
        loadAvatar(directory.profile(post.authorUid)?.photoURL, for: post.id)

        textView.attributedText = Self.attributed(post.text, tickers: post.tickers)
        textView.isHidden = post.text.isEmpty
        showGallery(post.imageURLs, for: post.id)

        setCount(likeButton, post.likeCount, symbol: liked ? "heart.fill" : "heart",
                 tint: liked ? (UIColor(named: "downtrend") ?? .systemRed) : ProfileStyle.secondaryText)
        setCount(reshareButton, post.reshareCount, symbol: "arrow.2.squarepath",
                 tint: reshared ? (UIColor(named: "uptrend") ?? .systemGreen) : ProfileStyle.secondaryText)
        //Your own post can't be reshared by you.
        reshareButton.isEnabled = !isOwn || reshared
    }

    private func setCount(_ button: UIButton, _ count: Int, symbol: String, tint: UIColor) {
        button.configuration?.image = UIImage(systemName: symbol)
        button.configuration?.title = count > 0 ? "\(count)" : nil
        button.configuration?.baseForegroundColor = tint
    }

    private func loadAvatar(_ url: String?, for id: String) {
        avatar.image = UIImage(systemName: "person.crop.circle.fill")
        guard let url else { return }
        RemoteImageCache.shared.load(url) { [weak self] image in
            guard let self, self.postId == id, let image else { return }
            self.avatar.image = image
        }
    }

    ///One photo full width, two side by side, three or four in a 2x2 grid.
    private func showGallery(_ urls: [String], for id: String) {
        imageURLs = urls
        gallery.arrangedSubviews.forEach { $0.removeFromSuperview() }
        gallery.isHidden = urls.isEmpty
        guard !urls.isEmpty else { return }
        let rows = urls.count <= 2 ? [Array(urls)] : [Array(urls.prefix(2)), Array(urls.dropFirst(2))]
        for row in rows {
            let line = UIStackView()
            line.spacing = 2
            line.distribution = .fillEqually
            for url in row {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.isUserInteractionEnabled = true
                imageView.accessibilityLabel = "Photo"
                imageView.accessibilityTraits = .button
                let index = urls.firstIndex(of: url) ?? 0
                imageView.addGestureRecognizer(PhotoTap(index: index, target: self, action: #selector(photoTapped(_:))))
                imageView.backgroundColor = ProfileStyle.text.withAlphaComponent(0.06)
                line.addArrangedSubview(imageView)
                RemoteImageCache.shared.load(url) { [weak self, weak imageView] image in
                    guard self?.postId == id else { return }
                    imageView?.image = image
                }
            }
            gallery.addArrangedSubview(line)
        }
    }

    // MARK: - Text

    ///The text in the body font, with each $TICKER a link the delegate opens as a chart.
    static func attributed(_ text: String, tickers: [String]) -> NSAttributedString {
        let font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: ProfileStyle.text])
        guard !tickers.isEmpty, let regex = try? NSRegularExpression(pattern: #"\$([A-Za-z]{1,5}(?:\.[A-Za-z])?)\b"#) else { return result }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let symbol = text[range].uppercased()
            guard tickers.contains(symbol), let url = URL(string: "bullishsquare-ticker:\(symbol)") else { continue }
            result.addAttribute(.link, value: url, range: match.range)
        }
        return result
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content, url.scheme == "bullishsquare-ticker" else { return defaultAction }
        let symbol = url.absoluteString.replacingOccurrences(of: "bullishsquare-ticker:", with: "")
        return UIAction { [weak self] _ in self?.onTicker?(symbol) }
    }

    ///"now", "5m", "3h", "2d", then the date.
    static func age(of date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        case ..<(7 * 86_400): return "\(Int(seconds / 86_400))d"
        default: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    // MARK: - Actions

    @objc private func authorTapped() {
        onAuthor?()
    }

    @objc private func photoTapped(_ recognizer: PhotoTap) {
        onPhoto?(imageURLs, recognizer.index)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        postId = nil
        onAuthor = nil
        onMore = nil
        onLike = nil
        onReshare = nil
        onTicker = nil
        onPhoto = nil
    }
}

///A tap on one photo of a post, carrying which one.
private final class PhotoTap: UITapGestureRecognizer {
    let index: Int

    init(index: Int, target: Any?, action: Selector?) {
        self.index = index
        super.init(target: target, action: action)
    }
}
