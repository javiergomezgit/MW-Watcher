import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import YPImagePicker

class EditProfileController: UITableViewController {
    
    var currentProfile: Profile?
    var updatedProfile = Profile(name: "", email: "")
    var editingField: String? // "name" or "email"
    var currentProfileImage: UIImage?
    var imageChanged = false
    var onSave: ((Profile) -> Void)?

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var imageViewProfile: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        populateFields()
        setupFieldEditing()
        
        imageViewProfile.image = SaveProfileInformation().loadImageProfile()
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
    
    private func setupFieldEditing() {
        // If we're editing a specific field, focus on it
        if let field = editingField {
            switch field {
            case "name":
                nameTextField.becomeFirstResponder()
            case "email":
                //emailTextField.becomeFirstResponder()
                print("somet")
            case "phone":
                phoneTextField.becomeFirstResponder()
            default:
                break
            }
        }
    }
    
    @IBAction func editPhotoButtonTapped(_ sender: UIButton) {
        var config = YPImagePickerConfiguration()
        // [Edit configuration here ...]
        //General config
        config.isScrollToChangeModesEnabled = true
        config.onlySquareImagesFromCamera = true
        config.usesFrontCamera = true
        config.showsPhotoFilters = false
        config.showsVideoTrimmer = false
        config.shouldSaveNewPicturesToAlbum = true
        config.albumName = "DefaultYPImagePickerAlbumName"
        config.startOnScreen = YPPickerScreen.photo
        config.screens = [.library, .photo]
        config.showsCrop = .circle // .none
        config.targetImageSize = YPImageSize.original
        config.overlayView = UIView()
        config.hidesStatusBar = true
        config.hidesBottomBar = false
        config.hidesCancelButton = false
        config.silentMode = true
        config.preferredStatusBarStyle = UIStatusBarStyle.default
        config.bottomMenuItemSelectedTextColour = UIColor.red // UIColor(r: 38/255, g: 38/255, b: 38/255, a: 1.0)
        config.bottomMenuItemUnSelectedTextColour = UIColor.yellow //UIColor(r: 153, g: 153, b: 153)
        //        config.filters = [DefaultYPFilters...]
        config.maxCameraZoomFactor = 1.0
        
        
        config.library.options = nil
        config.library.onlySquare = false
        config.library.isSquareByDefault = true
        config.library.minWidthForItem = nil
        config.library.mediaType = YPlibraryMediaType.photo
        config.library.defaultMultipleSelection = false
        config.library.maxNumberOfItems = 1
        config.library.minNumberOfItems = 1
        config.library.numberOfItemsInRow = 4
        config.library.spacingBetweenItems = 1.0
        config.library.skipSelectionsGallery = false
        config.library.preselectedItems = nil
        config.library.preSelectItemOnMultipleSelection = true
        
        
        config.gallery.hidesRemoveButton = false
        
        // Build a picker with your configuration
        let picker = YPImagePicker(configuration: config)
        
        picker.didFinishPicking { [unowned picker] items, _ in
            if let photo = items.singlePhoto {
                print(photo.fromCamera) // Image source (camera or library)
                print(photo.image) // Final image selected by the user
                print(photo.originalImage) // original image selected by the user, unfiltered
                //                print(photo.modifiedImage) // Transformed image, can be nil
                //                print(photo.exifMeta) // Print exif meta data of original image.
                self.imageViewProfile.image = photo.image
                self.imageChanged = true
            }
            picker.dismiss(animated: true, completion: nil)
        }
        present(picker, animated: true, completion: nil)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Save the changes
        saveProfile()
        //dismiss(animated: true)
    }
    
    private func saveProfile() {
        // Update the profile with new values
        updatedProfile.name = nameTextField.text ?? ""
        updatedProfile.email = emailTextField.text ?? ""
        updatedProfile.phoneNumber = phoneTextField.text ?? ""
        
        // Implement save logic
        // Update UserDefaults, Core Data, or API call
        saveUpdatedProfileFirebase()
    }
    
    private func saveUpdatedProfileFirebase() {
        guard let user = Auth.auth().currentUser else { return }
        if self.currentProfile!.email != self.updatedProfile.email {
            self.showPasswordAlert()
        } else {
            
            if imageChanged {
                
                guard let image = imageViewProfile.image else {
                    print("❌ No/invalid image data")
                    return
                }
                
                print("Image size:", image.size)
                
                SaveProfileInformation().saveImageProfile(imageProfile: image)
                
                let profileData: [String: Any] = [
                    "name": self.updatedProfile.name,
                    "phoneNumber": self.updatedProfile.phoneNumber!
                ]
                
                Firestore.firestore().collection("users").document(user.uid).updateData(profileData) { error in
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.currentProfile?.name = self.updatedProfile.name
                        self.currentProfile?.phoneNumber = self.updatedProfile.phoneNumber
                        self.nameTextField.text = self.updatedProfile.name
                        self.phoneTextField.text = self.updatedProfile.phoneNumber
                        
                        Utilities.showAlertWithCompletion(on: self, title: "Updated successfully", message: "Your profile was updated successfully.") {
                            let updated = self.updatedProfile
                            self.onSave?(updated)
                            self.dismiss(animated: true) {
                                if let nav = self.navigationController {
                                    nav.popViewController(animated: true)
                                } else {
                                    self.dismiss(animated: true)
                                }
                            }
                        }
                        print("Profile updated successfully!")
                    }
                }
                
            } else {
                
                let profileData: [String: Any] = [
                    "name": self.updatedProfile.name,
                    "phoneNumber": self.updatedProfile.phoneNumber!,
                ]
                Firestore.firestore().collection("users").document(user.uid).updateData(profileData) { error in
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                        return
                    }
                    DispatchQueue.main.async {
                        self.currentProfile?.name = self.updatedProfile.name
                        self.currentProfile?.phoneNumber = self.updatedProfile.phoneNumber
                        self.nameTextField.text = self.updatedProfile.name
                        self.phoneTextField.text = self.updatedProfile.phoneNumber
                        
                        Utilities.showAlertWithCompletion(on: self, title: "Updated successfully", message: "Your profile was updated successfully.") {
                            
                            let updated = self.updatedProfile
                            self.onSave?(updated)
                            self.dismiss(animated: true) {
                                if let nav = self.navigationController {
                                    nav.popViewController(animated: true)
                                } else {
                                    self.dismiss(animated: true)
                                }
                            }
                        }
                        print("Profile updated successfully!")
                    }
                }
            }
        }
    }
    
    func showPasswordAlert() {
        
        let alert = UIAlertController(title: "Enter Password", message: "Please enter your password to proceed.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
            guard let password = alert?.textFields?.first?.text, !password.isEmpty else {
                print("No password entered")
                return
            }
            print("Entered password: \(password)")
            
            let credential = EmailAuthProvider.credential(withEmail: self.currentProfile!.email, password: password)
            guard let user = Auth.auth().currentUser else { return }
            
            user.reauthenticate(with: credential) { result, error in
                if let error = error {
                    print("Reauthentication failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                    }
                } else {
                    print("Reauthentication successful ✅")
                    
                    let profileData: [String: Any] = [
                        "name": self.updatedProfile.name,
                        "email": self.currentProfile!.email,
                        "phoneNumber": self.updatedProfile.phoneNumber!,
                        "pendingEmail": self.updatedProfile.email
                    ]
                    
                    user.sendEmailVerification(beforeUpdatingEmail: self.currentProfile!.email) { error in
                        if let error = error {
                            print("Failed to update email in Auth: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                            }
                            return
                        }
                        
                        let verifyAlert = UIAlertController(
                            title: "Verify Email",
                            message: "A verification link was sent to \(self.updatedProfile.email). Please confirm it to complete the update.",
                            preferredStyle: .alert
                        )
                        
                        verifyAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                            DispatchQueue.main.async {
                                // Always dismiss any alert first
                                self.dismiss(animated: true) {
                                    if let nav = self.navigationController {
                                        nav.popViewController(animated: true)
                                    } else {
                                        self.dismiss(animated: true)
                                    }
                                }
                            }
                        }))
                        
                        DispatchQueue.main.async {
                            self.present(verifyAlert, animated: true)
                        }
                        
                        Firestore.firestore().collection("users").document(Auth.auth().currentUser!.uid).updateData(profileData) { error in
                            if let error = error {
                                print("Error updating profile: \(error.localizedDescription)")
                                return
                            }
                            print("Profile updated successfully!")
                        }
                    }
                }
            }
        }))
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }
    
}
