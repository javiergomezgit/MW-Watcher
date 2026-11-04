//
//  EditBioController.swift
//  Bullish Square
//

import UIKit
import YPImagePicker

///What the profile card shows of you that Personal Information does not: the photo and a
///short bio. Opened by tapping the card. (BS-260)
///
///The profile screen uploads the photo through ProfilePhotoStore. (BS-258)
final class EditBioController: UIViewController, UITextViewDelegate {

    // MARK: - Properties

    var onSave: ((_ bio: String, _ photo: UIImage?) -> Void)?

    private let bio: String
    private let photoView = UIImageView()
    private let textView = UITextView()
    private let counterLabel = UILabel()
    private let placeholderLabel = UILabel()
    private var newPhoto: UIImage?

    init(bio: String, photo: UIImage?) {
        self.bio = bio
        super.init(nibName: nil, bundle: nil)
        photoView.image = photo
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Profile"
        view.backgroundColor = ProfileStyle.background
        ProfileStyle.style(navigationController)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 48
        photoView.tintColor = ProfileStyle.secondaryText
        photoView.isUserInteractionEnabled = true
        photoView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped)))

        let changePhoto = UIButton(configuration: .plain())
        changePhoto.configuration?.title = "Change Photo"
        changePhoto.configuration?.baseForegroundColor = ProfileStyle.accent
        changePhoto.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)

        let bioTitle = UILabel()
        bioTitle.text = "Bio"
        bioTitle.font = .preferredFont(forTextStyle: .footnote)
        bioTitle.textColor = ProfileStyle.secondaryText

        textView.text = bio
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = ProfileStyle.card
        textView.textColor = ProfileStyle.text
        textView.tintColor = ProfileStyle.accent
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.delegate = self
        textView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        placeholderLabel.text = "What you trade, what you're learning…"
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.textColor = ProfileStyle.placeholder
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13)
        ])

        counterLabel.font = .preferredFont(forTextStyle: .caption1)
        counterLabel.textColor = ProfileStyle.secondaryText
        counterLabel.textAlignment = .right
        updateCounter()

        let photoStack = UIStackView(arrangedSubviews: [photoView, changePhoto])
        photoStack.axis = .vertical
        photoStack.alignment = .center
        photoStack.spacing = 4

        let stack = UIStackView(arrangedSubviews: [photoStack, bioTitle, textView, counterLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(24, after: photoStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            photoView.widthAnchor.constraint(equalToConstant: 96),
            photoView.heightAnchor.constraint(equalToConstant: 96),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    // MARK: - Bio

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= PublicProfileStore.bioMaximumLength
    }

    func textViewDidChange(_ textView: UITextView) {
        updateCounter()
    }

    private func updateCounter() {
        counterLabel.text = "\(textView.text.count)/\(PublicProfileStore.bioMaximumLength)"
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    // MARK: - Photo

    @objc private func changePhotoTapped() {
        var config = YPImagePickerConfiguration()
        config.onlySquareImagesFromCamera = true
        config.usesFrontCamera = true
        config.showsPhotoFilters = false
        config.shouldSaveNewPicturesToAlbum = false
        config.startOnScreen = .library
        config.screens = [.library, .photo]
        config.showsCrop = .circle
        config.hidesStatusBar = false
        config.library.mediaType = .photo
        config.library.maxNumberOfItems = 1
        config.library.isSquareByDefault = true

        let picker = YPImagePicker(configuration: config)
        picker.didFinishPicking { [weak self, unowned picker] items, _ in
            if let photo = items.singlePhoto {
                self?.newPhoto = photo.image
                self?.photoView.image = photo.image
            }
            picker.dismiss(animated: true)
        }
        present(picker, animated: true)
    }

    // MARK: - Saving

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    ///Saves through the profile screen, which owns the profile, and closes.
    @objc private func saveTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != bio || newPhoto != nil else {
            dismiss(animated: true)
            return
        }
        onSave?(text, newPhoto)
        dismiss(animated: true)
    }
}
