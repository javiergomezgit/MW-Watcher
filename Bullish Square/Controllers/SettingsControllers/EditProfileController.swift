import UIKit

class EditProfileController: UITableViewController {
    
    var currentProfile: Profile?
//    var editingField: String? // "name" or "email"
    var currentProfileImage: UIImage?
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        populateFields()
//        setupFieldEditing()
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
    }
    
    private func populateFields() {
        nameTextField.text = currentProfile?.name
        emailTextField.text = currentProfile?.email
        phoneTextField.text = currentProfile?.phoneNumber
    }
    
//    private func setupFieldEditing() {
//        // If we're editing a specific field, focus on it
//        if let field = editingField {
//            switch field {
//            case "name":
//                nameTextField.becomeFirstResponder()
//            case "email":
//                emailTextField.becomeFirstResponder()
//            default:
//                break
//            }
//        }
//    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Save the changes
        saveProfile()
        dismiss(animated: true)
    }
    
    private func saveProfile() {
        // Update the profile with new values
        currentProfile?.name = nameTextField.text ?? ""
        currentProfile?.email = emailTextField.text ?? ""
        currentProfile?.phoneNumber = phoneTextField.text
        
        // Implement save logic
        // Update UserDefaults, Core Data, or API call
    }
} 
