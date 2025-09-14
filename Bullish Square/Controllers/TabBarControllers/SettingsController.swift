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
        }
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
        getUserInfoFromFirebase()
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
            // Password and Security cell - navigate to security settings
            //navigateToSecuritySettings()
            print ("Future implementation")
        default:
            break
        }
    }
    
    private func handleLegalSection(row: Int) {
        // Your existing openBrowser logic
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
                content.secondaryText = self.currentProfile.email
                content.image = UIImage(systemName: "person.crop.square.fill")!
                cell.contentConfiguration = content
                //Maybe need to add something similar whe the image is updated too
                self.profileImageView.image = SaveProfileInformation().loadImageProfile()
            }
        }
    }
    
    private func navigateToSecuritySettings() {
        let storyboard = UIStoryboard(name: "SettingsTab", bundle: nil)
        if let securityVC = storyboard.instantiateViewController(withIdentifier: "SecuritySettingsController") as? SecuritySettingsController {
            securityVC.currentSettings = getSecuritySettings()
            
            let navigationController = UINavigationController(rootViewController: securityVC)
            present(navigationController, animated: true)
        }
    }
    
    // Helper methods to get current data
    private func getCurrentProfile() -> Profile {
        // Return current profile data
        
        let name = self.currentProfile.name
        let email = self.currentProfile.email
        let phoneNumber = self.currentProfile.phoneNumber
        let imageProfileURL = self.currentProfile.profileImage
        
        return Profile(name: name, email: email, phoneNumber: phoneNumber, profileImage: imageProfileURL)
    }
    
    //Populates fields with firebase information
    //Stores in local variable
    func getUserInfoFromFirebase() {
        let user = Auth.auth().currentUser
        
        if let user = user {
            let uid = user.uid
            let db = Firestore.firestore()

            db.collection("users").document(uid).getDocument { document, error in
                if let document = document, document.exists {
                    let data = document.data()!
                    print(data)
                    
                    let name = data["name"] as? String ?? ""
                    self.currentProfile.name = name
                    self.currentProfile.email = (data["email"] as? String)!
                    let phoneNumber = data["phoneNumber"] as? String ?? ""
                    self.currentProfile.phoneNumber = phoneNumber
                    let profileURL = data["profileURL"] as? String ?? ""
                    self.currentProfile.profileImage = profileURL
                    
                    DispatchQueue.main.async {
                        if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) {
                            var content = cell.defaultContentConfiguration()
                            content.text = self.currentProfile.name
                            content.secondaryText = self.currentProfile.email
                            //Not working yet, Firebase storage not working properly, saving in local database temporarily
                            //Calling downloading image from firebase to load the image in the profile view
                            content.image = UIImage(systemName: "person.crop.square.fill")!
                            cell.contentConfiguration = content
                        }
                    }
                } else {
                    print("Document does not exist")
                }
            }
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
    
    private func getSecuritySettings() -> SecuritySettings {
        // Return current security settings
        return SecuritySettings()
    }
    
    func openBrowser(selectedCell: Int) {
        var urlString = ""
        switch selectedCell {
        case 0:
            urlString = "https://jdevit.com/privacy-policy-bullish-square/"
        case 1:
            urlString = "https://jdevit.com/contact-bullish-square/"
        case 2:
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
