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
    
    override func viewWillAppear(_ animated: Bool) {
        //Temporarily
        profileImageView.image = SaveProfileInformation().loadImageProfile()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        versionLabel.text = "Version \(appVersion)"
        
        //Temporarily
        profileImageView.image = SaveProfileInformation().loadImageProfile()
        
        getUserInfoFromFirebase()
        //load image from database phone if empty download from firebase,
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
            
            let navigationController = UINavigationController(rootViewController: editProfileVC)
            present(navigationController, animated: true)
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
                            content.image = UIImage(systemName: "person.crop.square.fill")
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
