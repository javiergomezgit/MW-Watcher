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
        lockEmailUnlessPasswordAccount()
        
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
                if hasPasswordAccount { emailTextField.becomeFirstResponder() }
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
                self.imageViewProfile.image = photo.image
                self.imageChanged = true
            }
            picker.dismiss(animated: true, completion: nil)
        }
        present(picker, animated: true, completion: nil)
    }
    
    ///Only an email-and-password account can change its email here: the change is confirmed
    ///with the password. An Apple account has none, and was asked for one anyway. (BS-255)
    private var hasPasswordAccount: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == EmailAuthProviderID } ?? false
    }

    private func lockEmailUnlessPasswordAccount() {
        guard !hasPasswordAccount else { return }
        emailTextField.isEnabled = false
        emailTextField.textColor = .secondaryLabel
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        view.endEditing(true)
        let name = (nameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (emailTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = (phoneTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            Utilities.showErrorAlert(on: self, message: "Please enter your name.")
            return
        }
        updatedProfile = Profile(name: name, email: email, phoneNumber: phone,
                                 profileImage: currentProfile?.profileImage)

        let currentEmail = currentProfile?.email ?? Auth.auth().currentUser?.email ?? ""
        guard hasPasswordAccount, email.lowercased() != currentEmail.lowercased() else {
            saveProfileFields()
            return
        }
        guard email.contains("@"), email.contains(".") else {
            Utilities.showErrorAlert(on: self, message: "Please enter a valid email address.")
            return
        }
        confirmEmailChange(from: currentEmail, to: email)
    }

    ///Name and phone to `users/{uid}`, then the photo, so a save that failed does not leave a
    ///new photo on the phone. merge, not updateData, which fails when the document is missing.
    private func saveProfileFields(pendingEmail: String? = nil) {
        guard let user = Auth.auth().currentUser else { return }
        var profileData: [String: Any] = [
            "name": updatedProfile.name,
            "phoneNumber": updatedProfile.phoneNumber ?? ""
        ]
        if let pendingEmail {
            profileData["pendingEmail"] = pendingEmail
        }
        Firestore.firestore().collection("users").document(user.uid).setData(profileData, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error as NSError? {
                    print("Saving the profile failed: \(error.localizedDescription)")
                    Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                    return
                }
                if self.imageChanged, let image = self.imageViewProfile.image {
                    SaveProfileInformation().saveImageProfile(imageProfile: image)
                }
                //The email shown stays the current one until the new one is confirmed.
                var saved = self.updatedProfile
                saved.email = self.currentProfile?.email ?? saved.email
                self.currentProfile = saved
                self.onSave?(saved)

                let message = pendingEmail.map {
                    "We sent a link to \($0). Your email changes when you open it."
                } ?? "Your profile was updated."
                Utilities.showAlertWithCompletion(on: self, title: "Saved", message: message) {
                    self.dismiss(animated: true)
                }
            }
        }
    }

    ///Changing the sign-in email needs a recent sign-in, so the password is asked for first.
    ///The link goes to the new address; the email changes once it is opened.
    private func confirmEmailChange(from currentEmail: String, to newEmail: String) {
        let alert = UIAlertController(title: "Confirm with your password",
                                      message: "Enter your password to change your email to \(newEmail).",
                                      preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
            textField.textContentType = .password
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self, weak alert] _ in
            guard let self, let user = Auth.auth().currentUser else { return }
            guard let password = alert?.textFields?.first?.text, !password.isEmpty else {
                Utilities.showErrorAlert(on: self, message: "Please enter your password.")
                return
            }
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
            user.reauthenticate(with: credential) { _, error in
                if let error = error as NSError? {
                    print("Confirming the password failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                    }
                    return
                }
                user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                    DispatchQueue.main.async {
                        if let error = error as NSError? {
                            print("Sending the email change link failed: \(error.localizedDescription)")
                            Utilities.showErrorAlert(on: self, message: error.localizedDescription)
                            return
                        }
                        self.saveProfileFields(pendingEmail: newEmail)
                    }
                }
            }
        })
        present(alert, animated: true)
    }
    
}
