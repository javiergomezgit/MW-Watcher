import Foundation

struct Profile {
    var name: String
    var email: String
    var phoneNumber: String?
    var profileImage: String?
    
    init(name: String, email: String, phoneNumber: String? = nil, profileImage: String? = nil) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
    }
} 
