import Foundation

///How long someone has traded, for matching Apprentices with Bulls and pitching content at
///the right level. Stored by raw value on `profiles/{uid}`. (BS-259)
enum TradingExperience: String, CaseIterable {
    case beginner, intermediate, advanced

    var title: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .beginner: return "New to investing, learning the basics."
        case .intermediate: return "Trading for a while, building a strategy."
        case .advanced: return "Experienced, could teach others."
        }
    }
}

///What someone trades or wants to learn. In this order wherever they are listed. (BS-259)
enum TradingInterest: String, CaseIterable {
    case stocks, crypto, options, etfs, dividends
    case dayTrading = "day_trading"
    case longTerm = "long_term"

    var title: String {
        switch self {
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .options: return "Options"
        case .etfs: return "ETFs"
        case .dividends: return "Dividends"
        case .dayTrading: return "Day trading"
        case .longTerm: return "Long-term investing"
        }
    }
}

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
    ///Public. (BS-259)
    var experience: TradingExperience?
    var interests: [TradingInterest] = []
    
    init(name: String, email: String, phoneNumber: String? = nil, profileImage: String? = nil, username: String? = nil) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
        self.username = username
    }
} 
