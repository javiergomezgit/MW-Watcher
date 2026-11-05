//
//  CommunityProfileHeaderView.swift
//  Bullish Square
//

import UIKit

///The top of someone's Community profile: photo, @username, name, bio, experience and
///interests, their post, follower and following counts, and Follow. (BS-269)
final class CommunityProfileHeaderView: UIView {

    // MARK: - Callbacks

    var onFollow: (() -> Void)?
    var onFollowers: (() -> Void)?
    var onFollowing: (() -> Void)?
    var onPosts: (() -> Void)?

    // MARK: - Views

    private let avatar = UIImageView()
    private let handleLabel = UILabel()
    private let nameLabel = UILabel()
    private let bioLabel = UILabel()
    private let tradingLabel = UILabel()
    private let postsCount = UIButton(type: .system)
    private let followersCount = UIButton(type: .system)
    private let followingCount = UIButton(type: .system)
    private let followButton = UIButton(configuration: .filled())
    ///On your own profile, says this is the public view, what anyone else sees.
    private let previewLabel = UILabel()
    private var photoURL: String?

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 40
        avatar.tintColor = ProfileStyle.secondaryText
        avatar.image = UIImage(systemName: "person.crop.circle.fill")

        handleLabel.font = UIFont(name: "Avenir-Heavy", size: 22) ?? .systemFont(ofSize: 22, weight: .heavy)
        handleLabel.textColor = .label
        nameLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = ProfileStyle.secondaryText
        for label in [bioLabel, tradingLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        bioLabel.font = UIFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        bioLabel.textColor = ProfileStyle.text
        tradingLabel.font = UIFont(name: "Avenir-Book", size: 13) ?? .systemFont(ofSize: 13)
        tradingLabel.textColor = ProfileStyle.secondaryText

        for (button, action) in [(postsCount, { [weak self] in self?.onPosts?() }),
                                 (followersCount, { [weak self] in self?.onFollowers?() }),
                                 (followingCount, { [weak self] in self?.onFollowing?() })] as [(UIButton, () -> Void)] {
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        let counts = UIStackView(arrangedSubviews: [postsCount, followersCount, followingCount])
        counts.distribution = .fillEqually

        followButton.addAction(UIAction { [weak self] _ in self?.onFollow?() }, for: .touchUpInside)
        followButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        followButton.isHidden = true

        let eye = NSTextAttachment(image: UIImage(systemName: "eye")?.withTintColor(ProfileStyle.secondaryText, renderingMode: .alwaysOriginal) ?? UIImage())
        let preview = NSMutableAttributedString(attachment: eye)
        preview.append(NSAttributedString(string: "  This is how others see your profile"))
        previewLabel.attributedText = preview
        previewLabel.font = UIFont(name: "Avenir-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        previewLabel.textColor = ProfileStyle.secondaryText
        previewLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [previewLabel, avatar, handleLabel, nameLabel, bioLabel, tradingLabel, counts, followButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setCustomSpacing(12, after: previewLabel)
        stack.setCustomSpacing(12, after: avatar)
        stack.setCustomSpacing(12, after: tradingLabel)
        stack.setCustomSpacing(12, after: counts)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 80),
            avatar.heightAnchor.constraint(equalToConstant: 80),
            counts.widthAnchor.constraint(equalTo: stack.widthAnchor),
            followButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
        setCounts(nil)
    }

    // MARK: - Content

    func configure(uid: String) {
        let directory = AuthorDirectory.shared
        let profile = directory.profile(uid)
        handleLabel.text = directory.handle(uid)
        nameLabel.text = profile?.name
        nameLabel.isHidden = (profile?.name ?? "").isEmpty
        bioLabel.text = profile?.bio
        bioLabel.isHidden = (profile?.bio ?? "").isEmpty
        var trading: [String] = []
        if let experience = profile?.experience { trading.append(experience.title) }
        if let interests = profile?.interests, !interests.isEmpty { trading.append(interests.map(\.title).joined(separator: ", ")) }
        tradingLabel.text = trading.joined(separator: " · ")
        tradingLabel.isHidden = trading.isEmpty

        let url = profile?.photoURL
        guard url != photoURL else { return }
        photoURL = url
        avatar.image = UIImage(systemName: "person.crop.circle.fill")
        guard let url else { return }
        RemoteImageCache.shared.load(url) { [weak self] image in
            guard let self, self.photoURL == url, let image else { return }
            self.avatar.image = image
        }
    }

    ///nil shows dashes while counting.
    func setCounts(_ counts: CommunityStore.Counts?) {
        setCount(postsCount, counts?.posts, "Posts")
        setCount(followersCount, counts?.followers, counts?.followers == 1 ? "Follower" : "Followers")
        setCount(followingCount, counts?.following, "Following")
    }

    private func setCount(_ button: UIButton, _ value: Int?, _ label: String) {
        var config = UIButton.Configuration.plain()
        var number = AttributedString(value.map(String.init) ?? "–")
        number.font = UIFont(name: "Avenir-Heavy", size: 18) ?? .systemFont(ofSize: 18, weight: .heavy)
        number.foregroundColor = ProfileStyle.text
        var caption = AttributedString("\n" + label)
        caption.font = UIFont(name: "Avenir-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        caption.foregroundColor = ProfileStyle.secondaryText
        config.attributedTitle = number + caption
        config.titleAlignment = .center
        button.configuration = config
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
    }

    func setPreview(_ isOwn: Bool) {
        previewLabel.isHidden = !isOwn
    }

    ///Hidden on your own profile. Following shows as a quieter outline.
    func setFollow(isOwn: Bool, isFollowing: Bool?) {
        guard !isOwn, let isFollowing else {
            followButton.isHidden = true
            return
        }
        followButton.isHidden = false
        if isFollowing {
            var config = UIButton.Configuration.gray()
            config.title = "Following"
            config.baseForegroundColor = ProfileStyle.text
            config.baseBackgroundColor = ProfileStyle.card
            config.cornerStyle = .medium
            followButton.configuration = config
            followButton.configurationUpdateHandler = nil
        } else {
            AuthStyle.stylePrimary(followButton, title: "Follow")
        }
    }

    func setFollowEnabled(_ enabled: Bool) {
        followButton.isEnabled = enabled
    }
}
