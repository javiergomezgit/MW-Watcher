//
//  CommentCell.swift
//  Bullish Square
//

import UIKit

///One comment under a post: who and when, the text with tappable $tickers and links, and
///Reply. Built in code; the controller owns what the buttons do. (BS-273)
final class CommentCell: UITableViewCell, UITextViewDelegate {

    static let reuseIdentifier = "CommentCell"

    // MARK: - Callbacks

    var onAuthor: (() -> Void)?
    var onReply: (() -> Void)?
    var onMore: (() -> Void)?
    var onTicker: ((String) -> Void)?
    var onLink: ((URL) -> Void)?

    // MARK: - Views

    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let textView = UITextView()
    private let replyButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    ///The comment this cell shows now, so a late avatar for a reused cell is dropped.
    private var commentId: String?

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
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 16
        avatar.tintColor = ProfileStyle.secondaryText
        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        nameLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = ProfileStyle.secondaryText
        nameLabel.isUserInteractionEnabled = true
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.linkTextAttributes = [:]

        var reply = UIButton.Configuration.plain()
        reply.attributedTitle = AttributedString("Reply", attributes: AttributeContainer([
            .font: UIFont(name: "Avenir-Heavy", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .bold)]))
        reply.baseForegroundColor = ProfileStyle.secondaryText
        reply.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 8)
        replyButton.configuration = reply
        replyButton.addAction(UIAction { [weak self] _ in self?.onReply?() }, for: .touchUpInside)

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = ProfileStyle.secondaryText
        moreButton.accessibilityLabel = "More"
        moreButton.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [nameLabel, UIView(), moreButton])
        header.alignment = .center
        let body = UIStackView(arrangedSubviews: [header, textView, replyButton])
        body.axis = .vertical
        body.spacing = 2
        body.alignment = .leading
        header.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        textView.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true

        let row = UIStackView(arrangedSubviews: [avatar, body])
        row.spacing = 10
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 32),
            avatar.heightAnchor.constraint(equalToConstant: 32),
            moreButton.widthAnchor.constraint(equalToConstant: 28),
            moreButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: - Content

    func configure(_ comment: Comment) {
        commentId = comment.id
        let directory = AuthorDirectory.shared
        let meta = NSMutableAttributedString(string: directory.handle(comment.authorUid), attributes: [
            .font: UIFont(name: "Avenir-Heavy", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: ProfileStyle.text])
        if directory.isAutomated(comment.authorUid) {
            meta.append(NSAttributedString(string: " "))
            meta.append(ProfileStyle.automatedBadge(font: nameLabel.font))
        }
        meta.append(NSAttributedString(string: " · \(PostCell.age(of: comment.createdAt))", attributes: [
            .font: nameLabel.font as Any, .foregroundColor: ProfileStyle.secondaryText]))
        nameLabel.attributedText = meta
        textView.attributedText = PostCell.attributed(comment.text, tickers: comment.tickers)

        avatar.image = UIImage(systemName: "person.crop.circle.fill")
        if let url = directory.profile(comment.authorUid)?.photoURL {
            RemoteImageCache.shared.load(url) { [weak self] image in
                guard let self, self.commentId == comment.id, let image else { return }
                self.avatar.image = image
            }
        }
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

    // MARK: - Actions

    @objc private func authorTapped() {
        onAuthor?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        commentId = nil
        onAuthor = nil
        onReply = nil
        onMore = nil
        onTicker = nil
        onLink = nil
    }
}
