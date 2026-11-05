//
//  ComposePostController.swift
//  Bullish Square
//

import UIKit
import YPImagePicker

///Writing a Community post: up to 500 characters, up to four photos, and any $TICKER in the
///text becomes a link to its chart. Presented in its own navigation controller. (BS-267)
final class ComposePostController: UIViewController, UITextViewDelegate {

    // MARK: - Properties

    ///The post as saved, for the feed to show at the top straight away.
    var onPosted: ((Post) -> Void)?

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let counterLabel = UILabel()
    private let tickersLabel = UILabel()
    private let photoStrip = UIStackView()
    private let addPhotoButton = UIButton(configuration: .plain())
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var photos: [UIImage] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Post"
        view.backgroundColor = ProfileStyle.background
        ProfileStyle.style(navigationController)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Post", style: .done, target: self, action: #selector(postTapped))
        isModalInPresentation = true

        textView.font = UIFont(name: "Avenir-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
        textView.backgroundColor = ProfileStyle.card
        textView.textColor = ProfileStyle.text
        textView.tintColor = ProfileStyle.accent
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.delegate = self
        textView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        placeholderLabel.text = "Share an idea. Use $AAPL to link a ticker."
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = ProfileStyle.placeholder
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 15),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.frameLayoutGuide.trailingAnchor, constant: -15)
        ])

        for label in [counterLabel, tickersLabel] {
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textColor = ProfileStyle.secondaryText
        }
        counterLabel.textAlignment = .right
        let info = UIStackView(arrangedSubviews: [tickersLabel, counterLabel])

        photoStrip.spacing = 8
        photoStrip.heightAnchor.constraint(equalToConstant: 72).isActive = true

        addPhotoButton.configuration?.title = "Add Photos"
        addPhotoButton.configuration?.image = UIImage(systemName: "photo.on.rectangle")
        addPhotoButton.configuration?.imagePadding = 6
        addPhotoButton.configuration?.baseForegroundColor = ProfileStyle.accent
        addPhotoButton.contentHorizontalAlignment = .leading
        addPhotoButton.addAction(UIAction { [weak self] _ in self?.addPhotosTapped() }, for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.color = ProfileStyle.text

        let stack = UIStackView(arrangedSubviews: [textView, info, addPhotoButton, photoStrip, spinner])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])

        refresh()
        textView.becomeFirstResponder()
    }

    // MARK: - Text

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= Post.textMaximumLength
    }

    func textViewDidChange(_ textView: UITextView) {
        refresh()
    }

    ///The counter, the detected tickers, the photo strip and whether Post is allowed.
    private func refresh() {
        let text = textView.text ?? ""
        placeholderLabel.isHidden = !text.isEmpty
        counterLabel.text = "\(text.count)/\(Post.textMaximumLength)"
        let tickers = Post.tickers(in: text)
        tickersLabel.text = tickers.isEmpty ? nil : tickers.map { "$\($0)" }.joined(separator: " ")
        navigationItem.rightBarButtonItem?.isEnabled =
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
        addPhotoButton.isHidden = photos.count >= Post.imageMaximumCount
        showPhotos()
    }

    // MARK: - Photos

    private func addPhotosTapped() {
        var config = YPImagePickerConfiguration()
        config.showsPhotoFilters = false
        config.shouldSaveNewPicturesToAlbum = false
        config.startOnScreen = .library
        config.screens = [.library, .photo]
        config.hidesStatusBar = false
        config.library.mediaType = .photo
        config.library.maxNumberOfItems = Post.imageMaximumCount - photos.count
        config.library.defaultMultipleSelection = config.library.maxNumberOfItems > 1

        let picker = YPImagePicker(configuration: config)
        picker.didFinishPicking { [weak self, unowned picker] items, _ in
            for item in items {
                if case .photo(let photo) = item { self?.photos.append(photo.image) }
            }
            if let self { self.photos = Array(self.photos.prefix(Post.imageMaximumCount)) }
            self?.refresh()
            picker.dismiss(animated: true)
        }
        present(picker, animated: true)
    }

    ///A thumbnail for each photo, each with a button to take it out.
    private func showPhotos() {
        photoStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }
        photoStrip.isHidden = photos.isEmpty
        for (index, photo) in photos.enumerated() {
            let imageView = UIImageView(image: photo)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.isUserInteractionEnabled = true
            imageView.widthAnchor.constraint(equalToConstant: 72).isActive = true

            let remove = UIButton(type: .system)
            remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            remove.tintColor = .white
            remove.accessibilityLabel = "Remove photo"
            remove.addAction(UIAction { [weak self] _ in
                guard let self, index < self.photos.count else { return }
                self.photos.remove(at: index)
                self.refresh()
            }, for: .touchUpInside)
            remove.translatesAutoresizingMaskIntoConstraints = false
            imageView.addSubview(remove)
            NSLayoutConstraint.activate([
                remove.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 2),
                remove.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -2)
            ])
            photoStrip.addArrangedSubview(imageView)
        }
        photoStrip.addArrangedSubview(UIView())
    }

    // MARK: - Posting

    @objc private func cancelTapped() {
        let hasDraft = !(textView.text ?? "").isEmpty || !photos.isEmpty
        guard hasDraft else { return dismiss(animated: true) }
        let alert = UIAlertController(title: "Discard this post?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in self?.dismiss(animated: true) })
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true)
    }

    @objc private func postTapped() {
        view.endEditing(true)
        //The community guidelines' filter (BS-271).
        guard !CommunityGuidelines.containsObjectionableLanguage(textView.text ?? "") else {
            return Utilities.showAlert(on: self, title: "Can't Post",
                                       message: "Your post contains language that isn't allowed in Community. Edit it and try again.")
        }
        setBusy(true)
        CommunityStore.shared.createPost(text: textView.text ?? "", images: photos) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success(let post):
                self.onPosted?(post)
                self.dismiss(animated: true)
            case .failure(let error):
                Utilities.showAlert(on: self, title: "Can't Post", message: error.localizedDescription)
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        busy ? spinner.startAnimating() : spinner.stopAnimating()
        navigationItem.rightBarButtonItem?.isEnabled = !busy
        navigationItem.leftBarButtonItem?.isEnabled = !busy
        textView.isEditable = !busy
        addPhotoButton.isEnabled = !busy
    }
}
