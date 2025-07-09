import Foundation

struct Profile {
    var name: String
    var email: String
    var phoneNumber: String?
    
    init(name: String, email: String, phoneNumber: String? = nil) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
    }
} 