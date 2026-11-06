//
//  QuotedPostView.swift
//  Bullish Square
//

import UIKit

///The original inside a reshare: a smaller card under the person who reshared it, with the
///original's author, up to six lines of its text, and its first photo or its link card.
///$tickers, links and the photo still open; the reshare itself is the row's post. (BS-292)
final class QuotedPostView: UIView, UITextViewDelegate {

    // MARK: - Callbacks

    var onAuthor: (() -> Void)?
    var onTicker: ((String) -> Void)?
    var onLink: ((URL) -> Void)?
    var onPhoto: (([String], Int) -> Void)?

    // MARK: - Views

    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let header = UIStackView()
    private let textView = UITextView()
    private let photo = UIImageView()
    private let linkPreview = LinkPreviewView()
    private let unavailableLabel = UILabel()
    private var imageURLs: [String] = []
    ///The post shown now, so a late image for a reused cell is dropped.
    private var postId: String?

    private static let photoHeight: CGFloat = 150
    private static let maximumLines = 6

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = ProfileStyle.text.withAlphaComponent(0.12).cgColor
        clipsToBounds = true

        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 11
        avatar.tintColor = ProfileStyle.secondaryText
        nameLabel.font = UIFont(name: "Avenir-Heavy", size: 14) ?? .systemFont(ofSize: 14, weight: .heavy)
        nameLabel.textColor = .label
        nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        metaLabel.font = UIFont(name: "Avenir-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = ProfileStyle.secondaryText
        [avatar, nameLabel, metaLabel, UIView()].forEach(header.addArrangedSubview)
        header.alignment = .center
        header.spacing = 6
        header.isUserInteractionEnabled = true
        header.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = Self.maximumLines
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.delegate = self
        textView.linkTextAttributes = [:]

        photo.contentMode = .scaleAspectFill
        photo.clipsToBounds = true
        photo.layer.cornerRadius = 8
        photo.backgroundColor = ProfileStyle.text.withAlphaComponent(0.06)
        photo.isUserInteractionEnabled = true
        photo.accessibilityLabel = "Photo"
        photo.accessibilityTraits = .button
        photo.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))

        linkPreview.addAction(UIAction { [weak self] _ in
            guard let self, let url = self.linkPreview.url else { return }
            self.onLink?(url)
        }, for: .touchUpInside)

        unavailableLabel.text = "The original post was deleted."
        unavailableLabel.font = UIFont(name: "Avenir-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        unavailableLabel.textColor = ProfileStyle.secondaryText

        let stack = UIStackView(arrangedSubviews: [header, textView, photo, linkPreview, unavailableLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            avatar.widthAnchor.constraint(equalToConstant: 22),
            avatar.heightAnchor.constraint(equalToConstant: 22),
            photo.heightAnchor.constraint(equalToConstant: Self.photoHeight)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        //A CGColor doesn't follow light and dark mode by itself.
        layer.borderColor = ProfileStyle.text.withAlphaComponent(0.12).cgColor
    }

    // MARK: - Content

    ///`original` nil means it was deleted.
    func show(_ original: Post?) {
        postId = original?.id
        guard let post = original else {
            header.isHidden = true
            textView.isHidden = true
            photo.isHidden = true
            linkPreview.isHidden = true
            unavailableLabel.isHidden = false
            return
        }
        unavailableLabel.isHidden = true
        header.isHidden = false

        let directory = AuthorDirectory.shared
        nameLabel.text = directory.handle(post.authorUid)
        let age = PostCell.age(of: post.createdAt)
        if directory.isAutomated(post.authorUid) {
            let meta = ProfileStyle.automatedBadge(font: metaLabel.font)
            meta.append(NSAttributedString(string: " · \(age)",
                                           attributes: [.font: metaLabel.font as Any, .foregroundColor: ProfileStyle.secondaryText]))
            metaLabel.attributedText = meta
        } else {
            metaLabel.text = age
        }
        avatar.image = UIImage(systemName: "person.crop.circle.fill")
        if let url = directory.profile(post.authorUid)?.photoURL {
            RemoteImageCache.shared.load(url) { [weak self] image in
                guard let self, self.postId == post.id, let image else { return }
                self.avatar.image = image
            }
        }

        let link = PostCell.previewLink(for: post)
        let text = PostCell.attributed(post, link: link)
        textView.attributedText = text
        textView.isHidden = text.length == 0

        //The first photo stands for all of them; the viewer shows the rest.
        imageURLs = post.imageURLs
        photo.image = nil
        photo.isHidden = imageURLs.isEmpty
        if let first = imageURLs.first {
            RemoteImageCache.shared.load(first) { [weak self] image in
                guard let self, self.postId == post.id else { return }
                self.photo.image = image
            }
        }

        linkPreview.isHidden = link == nil
        if let link {
            let store = LinkPreviewStore.shared
            linkPreview.show(link, preview: store.cached(link))
            if store.cached(link) == nil {
                store.load(link) { [weak self] preview in
                    guard let self, self.postId == post.id else { return }
                    self.linkPreview.show(link, preview: preview)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func authorTapped() {
        onAuthor?()
    }

    @objc private func photoTapped() {
        guard !imageURLs.isEmpty else { return }
        onPhoto?(imageURLs, 0)
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else { return defaultAction }
        if url.scheme == "bullishsquare-ticker" {
            let symbol = url.absoluteString.replacingOccurrences(of: "bullishsquare-ticker:", with: "")
            return UIAction { [weak self] _ in self?.onTicker?(symbol) }
        }
        guard onLink != nil else { return defaultAction }
        return UIAction { [weak self] _ in self?.onLink?(url) }
    }

    ///For a reused cell: an image still loading for the last post is dropped. The callbacks
    ///stay, as the cell sets them once and forwards them.
    func prepareForReuse() {
        postId = nil
    }
}
