import Foundation

struct SecuritySettings {
    var biometricEnabled: Bool
    var requirePasscode: Bool
    var autoLockTimeout: Int
    
    init(biometricEnabled: Bool = false, requirePasscode: Bool = true, autoLockTimeout: Int = 5) {
        self.biometricEnabled = biometricEnabled
        self.requirePasscode = requirePasscode
        self.autoLockTimeout = autoLockTimeout
    }
} 