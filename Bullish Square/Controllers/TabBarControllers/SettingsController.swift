//
//  SettingsControllerTableViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/22.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsController: UITableViewController {
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameEmailCell: UITableViewCell!
    @IBOutlet weak var imageCell: UITableViewCell!
    
    var currentProfile = Profile(name: "Name", email: "Email")
    private var overlayView: UIView?
    ///One "sign in again" alert, not one per reload while it is up.
    private var showingSessionEnded = false

    
    override func viewWillAppear(_ animated: Bool) {
        //Temporarily
        profileImageView.image = SaveProfileInformation().loadImageProfile()
        
        // Check Firebase auth state
        if Auth.auth().currentUser == nil {
            // User is signed out – perform redirect, show login, or show alert
            showLoginOverlay()
        } else {
            // User is authenticated – proceed as normal
            hideLoginOverlay()
            //Every time, not just once: an email confirmed from the link, or a profile saved on
            //another phone, used to wait for the next launch. (BS-255)
            getUserInfoFromFirebase()
        }
    }
    
    ///Back from the Mail app after opening the email-change link.
    @objc private func appWillEnterForeground() {
        guard viewIfLoaded?.window != nil, Auth.auth().currentUser != nil else { return }
        getUserInfoFromFirebase()
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        versionLabel.text = "Version \(appVersion)"
        
        //Temporarily
        let imageProfile = SaveProfileInformation().loadImageProfile()
        if imageProfile.size.width == 0 {
            DispatchQueue.main.async{
                let tempImage = UIImage(named: "person.circle.fill")!
                self.profileImageView.image = tempImage
                SaveProfileInformation().saveImageProfile(imageProfile: UIImage(named: "person.circle.fill")!)
            }
        } else {
            DispatchQueue.main.async{
                self.profileImageView.image = imageProfile
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle different sections
        switch indexPath.section {
        case 0:
            // Profile section - handle name and email cell taps
            //Future -> separate photo editing from email/name
            //handleProfilePhotoSection()
            navigateToEditProfile()
        case 1:
            // Account section
            handleAccountSection(row: indexPath.row)
        case 2:
            // Legal/Support section
            handleLegalSection(row: indexPath.row)
        default:
            break
        }
    }
        
    private func handleAccountSection(row: Int) {
        switch row {
        case 0:
            // Profile info cell - navigate to edit profile
            navigateToEditProfile()
        case 1:
            //Password and Security. The row only printed "Future implementation". (BS-256)
            navigateToChangePassword()
        default:
            break
        }
    }
    
    private func handleLegalSection(row: Int) {
        //Only the first five rows are links. The rows below them hold the Logout and
        //Delete Account buttons, and tapping the cell around a button used to fall through
        //to openBrowser's default case and open the website.
        guard row <= 4 else { return }
        openBrowser(selectedCell: row)
    }
    
//    private func handleProfilePhotoSection() {
//        let storyboard = UIStoryboard(name: "SettingsTab", bundle: nil)
//        if let editProfileVC = storyboard.instantiateViewController(withIdentifier: "EditProfileController") as? EditProfileController {
//            editProfileVC.currentProfileImage = getCurrentImageProfile()
//            
//            let navigationController = UINavigationController(rootViewController: editProfileVC)
//            present(navigationController, animated: true)
//        }
//    }
    
    private func navigateToEditProfile() {
        let storyboard = UIStoryboard(name: "SettingsTab", bundle: nil)
        if let editProfileVC = storyboard.instantiateViewController(withIdentifier: "EditProfileController") as? EditProfileController {
            editProfileVC.currentProfile = getCurrentProfile()
            editProfileVC.onSave = { [weak self] updated in
                    self?.currentProfile = updated
                    self?.refreshUI()
                }
            
            let navigationController = UINavigationController(rootViewController: editProfileVC)
            present(navigationController, animated: true)
        }
    }
    
    private func refreshUI() {
        DispatchQueue.main.async {
            if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) {
                var content = cell.defaultContentConfiguration()
                content.text = self.currentProfile.name
                content.secondaryText = [self.currentProfile.username.map { "@\($0)" }, self.currentProfile.email]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                content.image = UIImage(systemName: "person.crop.square.fill")!
                cell.contentConfiguration = content
                //Maybe need to add something similar whe the image is updated too
                self.profileImageView.image = SaveProfileInformation().loadImageProfile()
            }
        }
    }
    
    private func navigateToChangePassword() {
        let navigationController = UINavigationController(rootViewController: ChangePasswordController())
        present(navigationController, animated: true)
    }
    
    ///A copy for the editor, every field, the username included.
    private func getCurrentProfile() -> Profile {
        currentProfile
    }
    
    ///Fills the profile from `users/{uid}`. The email comes from the account itself: a
    ///confirmed email change updates the account, not the document, and a document without
    ///an email (an Apple account that hid it, an old account) used to crash here. (BS-255)
    func getUserInfoFromFirebase() {
        guard let user = Auth.auth().currentUser else { return }
        //Reloaded first, so an email change confirmed from the link is seen.
        user.reload { [weak self] error in
            //Firebase ends the session once a new email is confirmed, so the reload is refused
            //and the cached account still has the old address. Sign in again with the new one.
            if let error = error as NSError?,
               [AuthErrorCode.userTokenExpired.rawValue, AuthErrorCode.invalidUserToken.rawValue].contains(error.code) {
                DispatchQueue.main.async { self?.sessionEnded() }
                return
            }
            let user = Auth.auth().currentUser ?? user
            let document = Firestore.firestore().collection("users").document(user.uid)
            document.getDocument { snapshot, error in
                if let error = error as NSError? {
                    print("Loading the profile failed: \(error.localizedDescription)")
                    return
                }
                let data = snapshot?.data() ?? [:]
                let accountEmail = user.email ?? data["email"] as? String ?? ""
                //The confirmed change reaches the document once, here.
                if let stored = data["email"] as? String, !accountEmail.isEmpty, stored != accountEmail {
                    document.setData(["email": accountEmail, "pendingEmail": FieldValue.delete()], merge: true)
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.currentProfile.name = data["name"] as? String ?? ""
                    self.currentProfile.email = accountEmail
                    self.currentProfile.phoneNumber = data["phoneNumber"] as? String ?? ""
                    self.currentProfile.profileImage = data["profileURL"] as? String ?? ""
                    self.refreshUI()
                    self.loadPublicProfile(uid: user.uid, privateName: self.currentProfile.name)
                }
            }
        }
    }
    
    ///The @handle, and the public name kept in step with the private one: accounts made
    ///before profiles/{uid} existed get theirs on the first visit. (BS-257)
    private func loadPublicProfile(uid: String, privateName: String) {
        PublicProfileStore.shared.loadProfile(uid: uid) { profile in
            if !privateName.isEmpty, let profile, profile.name != privateName {
                PublicProfileStore.shared.publish(name: privateName)
            }
            PublicProfileStore.shared.ensureUsername { [weak self] username in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.currentProfile.username = username
                    self.refreshUI()
                }
            }
        }
    }
    
    private func sessionEnded() {
        guard !showingSessionEnded else { return }
        showingSessionEnded = true
        Utilities.showAlertWithCompletion(on: self, title: "Please Sign In Again",
                                          message: "Your account details changed, for example your email. Sign in again, with your new email if you changed it.") {
            self.showingSessionEnded = false
            self.logoutFirebase()
        }
    }
    
    //Not working yet, Firebase storage not working properly, saving in local database temporarily
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error downloading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
    
    func openBrowser(selectedCell: Int) {
        var urlString = ""
        switch selectedCell {
        case 0:
            urlString = "https://jdevit.com/privacy-policy-bullish-square/"
        case 1:
            urlString = "https://www.jdevit.com/terms-of-service-bullish-square/"
        case 2:
            urlString = "https://www.jdevit.com/disclaimer-bullish-square/"
        case 3:
            urlString = "https://jdevit.com/contact-bullish-square/"
        case 4:
            urlString = "https://jdevit.com/contact-bullish-square/"
        default:
            urlString = "https://www.jdevit.com/"
        }
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "browser") as? BrowserController
        
        destination!.urlString = urlString
        destination!.modalTransitionStyle = .crossDissolve
        //        destination!.modalPresentationStyle = .overCurrentContext
        self.present(destination!, animated: true, completion: nil)
    }
    
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        logoutFirebase()
    }
    
    @IBAction func deleteAccountButtonTapped(_ sender: UIButton) {
        confirmAccountDeletion()
    }
    
    //App Review 5.1.1(v) requires an in-app deletion path for any app that creates
    //accounts. Two steps, because nothing here can be undone.
    private func confirmAccountDeletion() {
        let alert = UIAlertController(
            title: "Delete Account?",
            message: "This permanently deletes your account, your profile, and everything saved on this device. It cannot be undone.",
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
                    //Same teardown as signing out: the account is gone, so the app has to
                    //come back up on the login screen.
                    self.handleLogout()
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
    
    private func logoutFirebase() {
        do {
            try Auth.auth().signOut()
            print("User logged out successfully from firebase")
            
            // Remove UID from Keychain
            if KeychainManager.deleteUID() {
                print("Removed UID from Keychain")
            } else {
                print("No UID found in Keychain to remove")
            }
            
            handleLogout()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    private func handleLogout() {
        UserDefaults.standard.removeObject(forKey: "authToken") //check
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let loginVC = storyboard.instantiateInitialViewController()!
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.window?.rootViewController = loginVC
        }
    }
    
}


extension SettingsController {
    
    func showLoginOverlay() {
        guard overlayView == nil else { return }
        
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor(named: "colorPrimary")?.withAlphaComponent(0.8) ?? .black.withAlphaComponent(0.8)
        overlay.alpha = 0
        
        let label = PaddedLabel()
        label.text = "Please Sign In to continue"
        label.textColor = .white
        label.backgroundColor = UIColor(named: "colorSecondary")
        label.textAlignment = .center
        label.textColor = UIColor(named: "colorPrimary")
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .custom)
        button.setTitle("Sign In", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(named: "colorAccent")
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 10
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(navigateToLogin), for: .touchUpInside)
        
        overlay.addSubview(label)
        overlay.addSubview(button)
        view.addSubview(overlay)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -30),
            label.widthAnchor.constraint(equalToConstant: 280),
            label.heightAnchor.constraint(equalToConstant: 62),
            
            button.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            button.widthAnchor.constraint(equalToConstant: 160),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        overlayView = overlay
        
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }
    
    func hideLoginOverlay() {
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayView?.alpha = 0
        }, completion: { _ in
            self.overlayView?.removeFromSuperview()
            self.overlayView = nil
        })
    }
    
    @objc private func navigateToLogin() {
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let signInVC = storyboard.instantiateViewController(withIdentifier: "SignInViewController")
        signInVC.modalPresentationStyle = .fullScreen
        present(signInVC, animated: true, completion: nil)
    }
}


// PaddedLabel from prior question
class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12) {
        didSet { setNeedsDisplay() }
    }
    
    override func drawText(in rect: CGRect) {
        let insetRect = rect.inset(by: textInsets)
        super.drawText(in: insetRect)
    }
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.width += textInsets.left + textInsets.right
        contentSize.height += textInsets.top + textInsets.bottom
        return contentSize
    }
}
