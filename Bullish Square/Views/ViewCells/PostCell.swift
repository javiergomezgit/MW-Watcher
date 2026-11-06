//
//  PostCell.swift
//  Bullish Square
//

import UIKit

///One post in a Community feed: who and when, the text with tappable $tickers, up to four
///photos or a link's preview card, and like, reshare and comment counts. A reshare is the
///resharer's own post, with the original quoted under it. (BS-292)
///Built in code; the controller owns what the buttons do. (BS-266)
final class PostCell: UITableViewCell, UITextViewDelegate {

    static let reuseIdentifier = "PostCell"

    // MARK: - Callbacks

    var onAuthor: (() -> Void)?
    ///The quoted original's author, in a reshare. (BS-292)
    var onOriginalAuthor: (() -> Void)?
    var onMore: (() -> Void)?
    var onLike: (() -> Void)?
    var onReshare: (() -> Void)?
    ///The comment button: opens the post's comments. (BS-273)
    var onComment: (() -> Void)?
    var onTicker: ((String) -> Void)?
    ///A web link in the text was tapped.
    var onLink: ((URL) -> Void)?
    ///A photo was tapped: the post's photo URLs and which one.
    var onPhoto: (([String], Int) -> Void)?

    // MARK: - Views

    private let card = UIView()
    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let moreButton = UIButton(type: .system)
    private let textView = UITextView()
    private let gallery = UIStackView()
    private let linkPreview = LinkPreviewView()
    private let quoted = QuotedPostView()
    private let likeButton = UIButton(type: .system)
    private let reshareButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let footer = UIStackView()
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
        //Empty, so each link keeps the colour and weight `attributed` gives it.
        textView.linkTextAttributes = [:]

        linkPreview.addAction(UIAction { [weak self] _ in
            guard let self, let url = self.linkPreview.url else { return }
            self.onLink?(url)
        }, for: .touchUpInside)

        quoted.onAuthor = { [weak self] in self?.onOriginalAuthor?() }
        quoted.onTicker = { [weak self] symbol in self?.onTicker?(symbol) }
        quoted.onLink = { [weak self] url in self?.onLink?(url) }
        quoted.onPhoto = { [weak self] urls, index in self?.onPhoto?(urls, index) }

        gallery.axis = .vertical
        gallery.spacing = 2
        gallery.layer.cornerRadius = 10
        gallery.clipsToBounds = true

        for (button, symbol, label) in [(likeButton, "heart", "Like"), (reshareButton, "arrow.2.squarepath", "Reshare"),
                                        (commentButton, "bubble.right", "Comments")] {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: symbol)
            config.imagePadding = 6
            config.baseForegroundColor = ProfileStyle.secondaryText
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 2)
            button.configuration = config
            button.accessibilityLabel = label
            //At their own width: the spacer after them takes the slack, so no icon or count is
            //squeezed and cut off. (BS-273)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        likeButton.addAction(UIAction { [weak self] _ in self?.onLike?() }, for: .touchUpInside)
        reshareButton.addAction(UIAction { [weak self] _ in self?.onReshare?() }, for: .touchUpInside)
        commentButton.addAction(UIAction { [weak self] _ in self?.onComment?() }, for: .touchUpInside)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [likeButton, reshareButton, commentButton, spacer].forEach(footer.addArrangedSubview)
        footer.spacing = 24

        let stack = UIStackView(arrangedSubviews: [header, textView, gallery, linkPreview, quoted, footer])
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

    ///`post` is the row's own post. A reshare is the resharer's: its likes and comments are
    ///its own, and `original` is quoted under it, nil when it was deleted. (BS-292)
    ///`reshared` and `isOwn` are about what the reshare button reshares, the original for a
    ///reshare. `comments` is the post's comment count, nil while it is unknown.
    func configure(_ post: Post, original: Post?, liked: Bool, reshared: Bool, isOwn: Bool, comments: Int? = nil) {
        postId = post.id
        let directory = AuthorDirectory.shared
        //The @username is who posted; the name stays on their profile.
        nameLabel.text = directory.handle(post.authorUid)
        let metaAttributes: [NSAttributedString.Key: Any] = [.font: metaLabel.font as Any, .foregroundColor: ProfileStyle.secondaryText]
        let meta = NSMutableAttributedString()
        if directory.isAutomated(post.authorUid) {
            meta.append(ProfileStyle.automatedBadge(font: metaLabel.font))
            meta.append(NSAttributedString(string: " · ", attributes: metaAttributes))
        }
        let age = Self.age(of: post.createdAt)
        meta.append(NSAttributedString(string: post.isReshare ? "↻ Reshared · \(age)" : age, attributes: metaAttributes))
        metaLabel.attributedText = meta
        loadAvatar(directory.profile(post.authorUid)?.photoURL, for: post.id)

        if post.isReshare {
            //A reshare has no text or photos of its own.
            textView.attributedText = nil
            textView.isHidden = true
            showGallery([], for: post.id)
            linkPreview.isHidden = true
            quoted.isHidden = false
            quoted.show(original)
        } else {
            quoted.isHidden = true
            let link = Self.previewLink(for: post)
            let text = Self.attributed(post, link: link)
            textView.attributedText = text
            textView.isHidden = text.length == 0
            showGallery(post.imageURLs, for: post.id)
            showLinkPreview(link, for: post)
        }

        setCount(likeButton, post.likeCount, symbol: liked ? "heart.fill" : "heart",
                 tint: liked ? (UIColor(named: "downtrend") ?? .systemRed) : ProfileStyle.secondaryText)
        //Nothing left to reshare once the original is deleted.
        reshareButton.isHidden = post.isReshare && original == nil
        setCount(reshareButton, (original ?? post).reshareCount, symbol: "arrow.2.squarepath",
                 tint: reshared ? (UIColor(named: "uptrend") ?? .systemGreen) : ProfileStyle.secondaryText)
        setCount(commentButton, comments ?? 0, symbol: "bubble.right", tint: ProfileStyle.secondaryText)
        //Your own post can't be reshared by you.
        reshareButton.isEnabled = !isOwn || reshared
    }

    ///The post alone, without its like, reshare and comment row: the top of its comments,
    ///where those would repeat the screen's own actions.
    func setActionsHidden(_ hidden: Bool) {
        footer.isHidden = hidden
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

    ///The first link's card, for a post without photos; photos say more than a page's
    ///picture. (BS-289)
    private func showLinkPreview(_ url: URL?, for post: Post) {
        guard let url else {
            linkPreview.isHidden = true
            return
        }
        linkPreview.isHidden = false
        let store = LinkPreviewStore.shared
        linkPreview.show(url, preview: store.cached(url))
        guard store.cached(url) == nil else { return }
        store.load(url) { [weak self] preview in
            guard let self, self.postId == post.id else { return }
            self.linkPreview.show(url, preview: preview)
        }
    }

    // MARK: - Text

    ///Links are bold. Web links are a light blue, so they stand apart from the green $tickers.
    private static let webLinkColor = UIColor(red: 0.302, green: 0.698, blue: 1, alpha: 1)
    private static let tickerColor = UIColor(named: "uptrend") ?? ProfileStyle.accent

    ///The page a post's card shows: the article a bot named in `sourceURL`, else the first web
    ///link in the text. None when the post has photos; they take the card's place.
    static func previewLink(for post: Post) -> URL? {
        guard post.imageURLs.isEmpty else { return nil }
        return post.sourceURL ?? LinkPreviewStore.firstLink(in: post.text)
    }

    ///A post's text under its card: the card's address is left out when it ends the text, as
    ///tapping the card opens it, and the name in a "Source: CNBC" line links to it instead.
    static func attributed(_ post: Post, link: URL?) -> NSAttributedString {
        guard let link else { return attributed(post.text, tickers: post.tickers) }
        let text = withoutTrailingLink(link, in: post.text)
        let result = NSMutableAttributedString(attributedString: attributed(text, tickers: post.tickers))
        let boldFont = UIFont(name: "Avenir-Heavy", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        if let regex = try? NSRegularExpression(pattern: #"(?m)^Source: ([^·\n]*[^·\s])"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            result.addAttributes([.link: link, .foregroundColor: webLinkColor, .font: boldFont], range: match.range(at: 1))
        }
        return result
    }

    ///`text` without `link` when the link is the last thing in it, along with the space before it.
    ///A link in the middle of a sentence stays, as the sentence needs it.
    static func withoutTrailingLink(_ link: URL, in text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let last = detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let found = last.url, samePage(found, link),
              let range = Range(last.range, in: text),
              text[range.upperBound...].allSatisfy(\.isWhitespace) else { return text }
        var kept = text[..<range.lowerBound]
        while kept.last?.isWhitespace == true { kept.removeLast() }
        return String(kept)
    }

    ///The same address whatever the scheme or "www." ("cnbc.com/a" is found as http://cnbc.com/a).
    private static func samePage(_ a: URL, _ b: URL) -> Bool {
        func key(_ url: URL) -> String {
            let host = (url.host ?? "").lowercased()
            return (host.hasPrefix("www.") ? String(host.dropFirst(4)) : host) + url.path + (url.query.map { "?" + $0 } ?? "")
        }
        return key(a) == key(b)
    }

    ///The text in the body font, with each $TICKER a link the delegate opens as a chart, and
    ///each web address ("https://…", "www.…", "cnbc.com/…") a link opened in the app.
    static func attributed(_ text: String, tickers: [String]) -> NSAttributedString {
        let font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        let boldFont = UIFont(name: "Avenir-Heavy", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: ProfileStyle.text])
        let whole = NSRange(text.startIndex..., in: text)
        if !tickers.isEmpty, let regex = try? NSRegularExpression(pattern: #"\$([A-Za-z]{1,5}(?:\.[A-Za-z])?)\b"#) {
            for match in regex.matches(in: text, range: whole) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let symbol = text[range].uppercased()
                guard tickers.contains(symbol), let url = URL(string: "bullishsquare-ticker:\(symbol)") else { continue }
                result.addAttributes([.link: url, .foregroundColor: tickerColor, .font: boldFont], range: match.range)
            }
        }
        //Web pages only: the detector also finds mailto: and other schemes, which stay text.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: text, range: whole) {
                guard let url = match.url, let scheme = url.scheme?.lowercased(),
                      scheme == "http" || scheme == "https" else { continue }
                result.addAttributes([.link: url, .foregroundColor: webLinkColor, .font: boldFont], range: match.range)
            }
        }
        return result
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else { return defaultAction }
        if url.scheme == "bullishsquare-ticker" {
            let symbol = url.absoluteString.replacingOccurrences(of: "bullishsquare-ticker:", with: "")
            return UIAction { [weak self] _ in self?.onTicker?(symbol) }
        }
        //A web link opens inside the app, like a news article, not by leaving for Safari.
        guard onLink != nil else { return defaultAction }
        return UIAction { [weak self] _ in self?.onLink?(url) }
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
        onOriginalAuthor = nil
        quoted.prepareForReuse()
        onMore = nil
        onLike = nil
        onReshare = nil
        onComment = nil
        footer.isHidden = false
        onTicker = nil
        onLink = nil
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
