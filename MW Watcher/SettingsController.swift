//
//  SettingsControllerTableViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/22.
//

import UIKit

class SettingsController: UITableViewController {

    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        versionLabel.text = "Version \(appVersion)"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        print("tapped \(row)")
        
        openBrowser(selectedCell: row)
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
