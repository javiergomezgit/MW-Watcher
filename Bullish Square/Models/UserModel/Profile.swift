import Foundation

struct Profile {
    var name: String
    var email: String
    var phoneNumber: String?
    var profileImage: String?
    ///The public @handle, from `profiles/{uid}`; nil until one is chosen. (BS-257)
    var username: String?
    ///Public, on `profiles/{uid}`. (BS-260)
    var bio: String?
    var memberSince: Date?
    
    init(name: String, email: String, phoneNumber: String? = nil, profileImage: String? = nil, username: String? = nil) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
        self.username = username
    }
} 
