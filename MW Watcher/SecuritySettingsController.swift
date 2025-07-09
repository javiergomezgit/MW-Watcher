import UIKit

class SecuritySettingsController: UITableViewController {
    
    var currentSettings: SecuritySettings?
    
//    @IBOutlet weak var biometricSwitch: UISwitch!
//    @IBOutlet weak var passcodeSwitch: UISwitch!
//    @IBOutlet weak var autoLockLabel: UILabel!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        populateFields()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        title = "Security Settings"
    }
    
    private func populateFields() {
//        biometricSwitch.isOn = currentSettings?.biometricEnabled ?? false
//        passcodeSwitch.isOn = currentSettings?.requirePasscode ?? true
//        autoLockLabel.text = "\(currentSettings?.autoLockTimeout ?? 5) minutes"
        passwordTextField.text = "ººººººº"
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Save the changes
        saveSecuritySettings()
        dismiss(animated: true)
    }
    
    private func saveSecuritySettings() {
        // Implement save logic
        // Update UserDefaults, Core Data, or API call
        print("Saving security settings...")
    }
    
    @IBAction func biometricSwitchChanged(_ sender: UISwitch) {
        // Handle biometric switch change
    }
    
    @IBAction func passcodeSwitchChanged(_ sender: UISwitch) {
        // Handle passcode switch change
    }
}
