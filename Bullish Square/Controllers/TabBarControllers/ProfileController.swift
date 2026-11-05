//
//  ProfileController.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth

///The fourth tab's navigation controller. SettingsTab.storyboard keeps it for the tab bar item
///and Main.storyboard's reference; its first screen is built in code. (BS-260)
final class ProfileNavigationController: UINavigationController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewControllers = [ProfileController()]
    }
}

///The Profile tab, laid out like the system Settings app: who you are at the top (photo, name,
///@username, bio), then Personal Information, Legal, Support, Log Out and Delete Account.
///Replaces the storyboard Settings and Edit Profile screens. (BS-260)
///
///Its title is a TabTitleRow, as the other tabs' are, with the bar hidden while it shows;
///the system large title it had first disappeared.
final class ProfileController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Properties

    private enum Row {
        case header, communityProfile, blockedAccounts, personalInfo, privacy, terms, disclaimer, contact, logOut, deleteAccount
    }

    private let sections: [(title: String?, rows: [Row])] = [
        (nil, [.header]),
        ("Community", [.communityProfile, .blockedAccounts]),
        ("Account", [.personalInfo]),
        ("Legal", [.privacy, .terms, .disclaimer]),
        ("Support", [.contact]),
        (nil, [.logOut]),
        (nil, [.deleteAccount])
    ]

    private var profile = Profile(name: "", email: "")
    ///This account's photo; nil draws the placeholder. Set from the cache, then the cloud.
    private var photo: UIImage?
    ///Signed out, the table has no sections and this is its background. It used to be laid
    ///over the table, whose section headers showed through it.
    private lazy var signedOutView = makeSignedOutView()
    private var isSignedIn: Bool { Auth.auth().currentUser != nil }
    ///One "sign in again" alert, not one per reload while it is up.
    private var showingSessionEnded = false

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.backgroundColor = ProfileStyle.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        TabTitleRow(title: title, buttons: []).install(in: self)
        ProfileStyle.style(tableView)
        ProfileStyle.style(navigationController)
        tableView.register(ProfileHeaderCell.self, forCellReuseIdentifier: ProfileHeaderCell.identifier)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TabTitleRow.setBarHidden(true, for: self, animated: animated)
        ProfilePhotoStore.shared.removeLegacyPhoto()
        photo = Auth.auth().currentUser.flatMap { ProfilePhotoStore.shared.cachedPhoto(uid: $0.uid) }
        updateSignedInState()
        if isSignedIn {
            loadProfile()
        }
    }

    ///The screens it opens keep their bar, for their title and back button.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TabTitleRow.setBarHidden(false, for: self, animated: animated)
    }

    ///Back from the Mail app after opening the email-change link.
    @objc private func appWillEnterForeground() {
        guard viewIfLoaded?.window != nil, Auth.auth().currentUser != nil else { return }
        loadProfile()
    }

    // MARK: - Loading

    ///The private details, then the public ones. Accounts made before profiles/{uid} existed
    ///get their public name and a generated @username here, once.
    private func loadProfile() {
        AccountProfileStore.shared.load { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let account):
                    self.profile.name = account.name
                    self.profile.email = account.email
                    self.profile.phoneNumber = account.phoneNumber
                    self.tableView.reloadData()
                    self.loadPublicProfile()
                case .failure(.sessionEnded):
                    self.sessionEnded()
                case .failure:
                    break
                }
            }
        }
    }

    private func loadPublicProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let privateName = profile.name
        PublicProfileStore.shared.loadProfile(uid: uid) { [weak self] publicProfile in
            guard let publicProfile else { return }
            if !privateName.isEmpty, publicProfile.name != privateName {
                PublicProfileStore.shared.publish(name: privateName)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.profile.username = publicProfile.username
                self.profile.bio = publicProfile.bio
                self.profile.memberSince = publicProfile.memberSince ?? Auth.auth().currentUser?.metadata.creationDate
                self.profile.experience = publicProfile.experience
                self.profile.interests = publicProfile.interests
                self.tableView.reloadData()
            }
            ProfilePhotoStore.shared.refresh(uid: uid, urlString: publicProfile.photoURL) { [weak self] image in
                guard let self, let image else { return }
                self.photo = image
                self.tableView.reloadData()
            }
            guard (publicProfile.username ?? "").isEmpty else { return }
            PublicProfileStore.shared.ensureUsername { username in
                DispatchQueue.main.async {
                    guard let self, let username else { return }
                    self.profile.username = username
                    self.tableView.reloadData()
                }
            }
        }
    }

    ///"Intermediate · Stocks, Crypto, ETFs", or nil when neither is set.
    private func tradingSummary() -> String? {
        let parts = [profile.experience?.title,
                     profile.interests.isEmpty ? nil : profile.interests.map(\.title).joined(separator: ", ")]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func currentPhoto() -> UIImage? {
        photo ?? UIImage(systemName: "person.crop.circle.fill")
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        isSignedIn ? sections.count : 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        if row == .header {
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileHeaderCell.identifier, for: indexPath) as! ProfileHeaderCell
            cell.configure(photo: currentPhoto(), name: profile.name, username: profile.username, bio: profile.bio,
                           trading: tradingSummary())
            ProfileStyle.style(cell)
            return cell
        }

        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        ProfileStyle.style(cell)
        var content = cell.defaultContentConfiguration()
        ProfileStyle.style(&content)
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .communityProfile:
            content.text = "My Posts and Followers"
            content.image = UIImage(systemName: "person.2")
        case .blockedAccounts:
            content.text = "Blocked Accounts"
            content.image = UIImage(systemName: "hand.raised")
        case .personalInfo:
            content.text = "Personal Information"
            content.image = UIImage(systemName: "person.text.rectangle")
        case .privacy:
            content.text = "Privacy Policy"
            content.image = UIImage(systemName: "hand.raised")
        case .terms:
            content.text = "Terms of Service"
            content.image = UIImage(systemName: "doc.text")
        case .disclaimer:
            content.text = "Disclaimer"
            content.image = UIImage(systemName: "exclamationmark.triangle")
        case .contact:
            content.text = "Contact Us"
            content.image = UIImage(systemName: "envelope")
        case .logOut:
            content.text = "Log Out"
            content.textProperties.color = ProfileStyle.accent
            content.textProperties.alignment = .center
            cell.accessoryType = .none
        case .deleteAccount:
            content.text = "Delete Account"
            content.textProperties.color = ProfileStyle.destructive
            content.textProperties.alignment = .center
            cell.accessoryType = .none
        case .header:
            break
        }
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        ProfileStyle.style(headerFooter: view)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .header: editBio()
        case .communityProfile: openCommunityProfile()
        case .blockedAccounts: navigationController?.pushViewController(BlockedAccountsController(), animated: true)
        case .personalInfo: openPersonalInfo()
        case .privacy: openBrowser("https://jdevit.com/privacy-policy-bullish-square/")
        case .terms: openBrowser("https://www.jdevit.com/terms-of-service-bullish-square/")
        case .disclaimer: openBrowser("https://www.jdevit.com/disclaimer-bullish-square/")
        //The site's contact form; the Bullish Square page this pointed at does not work.
        case .contact: openBrowser("https://jdevit.com/contact")
        case .logOut: confirmLogOut()
        case .deleteAccount: confirmAccountDeletion()
        }
    }

    private func versionFooter() -> UIView {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        label.text = "Bullish Square \(version)"
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = ProfileStyle.secondaryText
        label.textAlignment = .center
        return label
    }

    // MARK: - Screens

    ///Your profile as others see it in Community, with your posts and counts. (BS-269)
    private func openCommunityProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        navigationController?.pushViewController(CommunityController(profileOf: uid), animated: true)
    }

    private func editBio() {
        let editor = EditBioController(bio: profile.bio ?? "", photo: currentPhoto())
        editor.onSave = { [weak self] bio, photo in
            guard let self else { return }
            if let newPhoto = photo {
                self.uploadPhoto(newPhoto)
            }
            guard bio != (self.profile.bio ?? "") else {
                self.tableView.reloadData()
                return
            }
            PublicProfileStore.shared.update(["bio": bio]) { error in
                DispatchQueue.main.async {
                    if let error {
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                        return
                    }
                    self.profile.bio = bio
                    self.tableView.reloadData()
                }
            }
        }
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    ///Shown straight away; on failure the previous photo comes back with the reason.
    private func uploadPhoto(_ newPhoto: UIImage) {
        let previous = photo
        photo = newPhoto
        tableView.reloadData()
        ProfilePhotoStore.shared.upload(newPhoto) { [weak self] error in
            guard let self, let error else { return }
            self.photo = previous
            self.tableView.reloadData()
            Utilities.showErrorAlert(on: self, message: "Your photo couldn't be saved. \(error.localizedDescription)")
        }
    }

    private func openPersonalInfo() {
        let personalInfo = PersonalInfoController(profile: profile)
        personalInfo.onChange = { [weak self] updated in
            self?.profile = updated
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(personalInfo, animated: true)
    }

    private func openBrowser(_ urlString: String) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let browser = storyboard.instantiateViewController(identifier: "browser") as? BrowserController else { return }
        browser.urlString = urlString
        browser.modalTransitionStyle = .crossDissolve
        present(browser, animated: true)
    }

    // MARK: - Log Out and Delete

    private func confirmLogOut() {
        let alert = UIAlertController(title: "Log Out?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in self?.logOut() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        present(alert, animated: true)
    }

    private func logOut() {
        do {
            try Auth.auth().signOut()
            if !KeychainManager.deleteUID() {
                print("No UID found in Keychain to remove")
            }
            showLoginScreen()
        } catch let error as NSError {
            print("Signing out failed: \(error.localizedDescription)")
            Utilities.showErrorAlert(on: self, message: error.localizedDescription)
        }
    }

    private func showLoginScreen() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        let loginVC = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()!
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.window?.rootViewController = loginVC
        }
    }

    ///App Review 5.1.1(v) requires an in-app deletion path for any app that creates
    ///accounts. Two steps, because nothing here can be undone.
    private func confirmAccountDeletion() {
        let alert = UIAlertController(
            title: "Delete Account?",
            message: "This permanently deletes your account, your profile and @username, and everything saved on this device. It cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            self?.performAccountDeletion()
        })
        present(alert, animated: true)
    }

    private func performAccountDeletion() {
        AccountDeletionManager.shared.deleteAccount(presentingOn: self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.showLoginScreen()
                case .failure(let error):
                    //Backing out of the password prompt or the Apple sheet is a normal
                    //outcome, not something to put an error in front of.
                    if let deletionError = error as? AccountDeletionManager.DeletionError,
                       case .cancelled = deletionError { return }
                    Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                }
            }
        }
    }

    ///Firebase ends the session once a new email is confirmed. Sign in again, with it.
    private func sessionEnded() {
        guard !showingSessionEnded else { return }
        showingSessionEnded = true
        Utilities.showAlertWithCompletion(on: self, title: "Please Sign In Again",
                                          message: "Your account details changed, for example your email. Sign in again, with your new email if you changed it.") {
            self.showingSessionEnded = false
            self.logOut()
        }
    }

    // MARK: - Signed out

    private func updateSignedInState() {
        tableView.backgroundView = isSignedIn ? nil : signedOutView
        tableView.tableFooterView = isSignedIn ? versionFooter() : UIView()
        tableView.isScrollEnabled = isSignedIn
        tableView.reloadData()
    }

    private func makeSignedOutView() -> UIView {
        let container = UIView()

        let icon = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        icon.tintColor = ProfileStyle.secondaryText
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .regular)

        let title = UILabel()
        title.text = "Your Profile"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = ProfileStyle.text
        title.textAlignment = .center

        let message = UILabel()
        message.text = "Sign in to choose a username, add a bio, and keep your watchlists on every device."
        message.font = .preferredFont(forTextStyle: .subheadline)
        message.textColor = ProfileStyle.secondaryText
        message.textAlignment = .center
        message.numberOfLines = 0

        let button = UIButton(configuration: .filled())
        button.configuration?.title = "Sign In"
        button.configuration?.cornerStyle = .large
        button.configuration?.baseBackgroundColor = ProfileStyle.accent
        button.addAction(UIAction { [weak self] _ in self?.navigateToLogin() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, title, message, button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10
        stack.setCustomSpacing(18, after: icon)
        stack.setCustomSpacing(24, after: message)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40)
        ])
        return container
    }

    private func navigateToLogin() {
        let signInVC = UIStoryboard(name: "Login", bundle: nil).instantiateViewController(withIdentifier: "SignInViewController")
        signInVC.modalPresentationStyle = .fullScreen
        present(signInVC, animated: true)
    }
}

// MARK: - Header cell

///Photo, name, @username and bio, as the top of a profile.
final class ProfileHeaderCell: UITableViewCell {

    static let identifier = "ProfileHeaderCell"

    private let photoView = UIImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let tradingLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 36
        photoView.tintColor = ProfileStyle.secondaryText

        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.textColor = ProfileStyle.text
        usernameLabel.font = .preferredFont(forTextStyle: .subheadline)
        usernameLabel.textColor = ProfileStyle.accent
        bioLabel.font = .preferredFont(forTextStyle: .subheadline)
        bioLabel.numberOfLines = 0
        tradingLabel.font = .preferredFont(forTextStyle: .footnote)
        tradingLabel.textColor = ProfileStyle.secondaryText
        tradingLabel.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [nameLabel, usernameLabel, tradingLabel])
        text.axis = .vertical
        text.spacing = 2
        let top = UIStackView(arrangedSubviews: [photoView, text])
        top.alignment = .center
        top.spacing = 14
        let stack = UIStackView(arrangedSubviews: [top, bioLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            photoView.widthAnchor.constraint(equalToConstant: 72),
            photoView.heightAnchor.constraint(equalToConstant: 72),
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    ///An empty bio invites one instead of leaving a gap.
    func configure(photo: UIImage?, name: String, username: String?, bio: String?, trading: String?) {
        tradingLabel.text = trading
        tradingLabel.isHidden = trading == nil
        photoView.image = photo
        nameLabel.text = name.isEmpty ? "Your name" : name
        usernameLabel.text = username.map { "@\($0)" } ?? " "
        if let bio, !bio.isEmpty {
            bioLabel.text = bio
            bioLabel.textColor = ProfileStyle.text
        } else {
            bioLabel.text = "Add a short bio"
            bioLabel.textColor = ProfileStyle.placeholder
        }
    }
}
