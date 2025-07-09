//
//  SettingsControllerTableViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/22.
//

import UIKit

class SettingsController: UITableViewController {

    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        versionLabel.text = "Version \(appVersion)"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle different sections
        switch indexPath.section {
        case 0:
            // Profile section - handle name and email cell taps
            handleProfilePhotoSection()
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
    
    @IBAction func changeImageButtonPressed(_ sender: UIButton) {
        
    }
    
    private func handleAccountSection(row: Int) {
        switch row {
        case 0:
            // Profile info cell - navigate to edit profile
            navigateToEditProfile()
        case 1:
            // Password and Security cell - navigate to security settings
            navigateToSecuritySettings()
        default:
            break
        }
    }

    private func handleLegalSection(row: Int) {
        // Your existing openBrowser logic
        openBrowser(selectedCell: row)
    }

    private func handleProfilePhotoSection() {
        let storyboard = UIStoryboard(name: "SettingsTab", bundle: nil)
        if let editProfileVC = storyboard.instantiateViewController(withIdentifier: "EditProfileController") as? EditProfileController {
            editProfileVC.currentProfileImage = getCurrentImageProfile() //getCurrentProfile()
            
            let navigationController = UINavigationController(rootViewController: editProfileVC)
            present(navigationController, animated: true)
        }
    }

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
        return Profile(name: "Javier Gomez", email: "javier.go.go@hotmail.com")
    }

    private func getSecuritySettings() -> SecuritySettings {
        // Return current security settings
        return SecuritySettings()
    }
    
    private func getCurrentImageProfile() -> UIImage {
        let image: UIImage?
        image = UIImage(systemName: "lock")
        return image!
    }

    func openBrowser(selectedCell: Int) {
        var urlString = ""
        switch selectedCell {
        case 0:
            urlString = "https://www.jdevprojects.com/privacy-policy-mw"
        case 1:
            urlString = "https://www.jdevprojects.com/contact-me-mw"
        case 2:
            urlString = "https://www.jdevprojects.com/contact-me-mw"
        default:
            urlString = "https://www.jdevprojects.com/"
        }
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "browser") as? BrowserController
        
        destination!.urlString = urlString
        destination!.modalTransitionStyle = .crossDissolve
//        destination!.modalPresentationStyle = .overCurrentContext
        self.present(destination!, animated: true, completion: nil)
    }
}
