//
//  ShowAlerts.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/16/21.
//

import UIKit

class ShowAlerts {
    
    ///Alert with no required answer/input from user
    static func showSimpleAlert(title: String?, message: String?, titleButton: String?, over viewController: UIViewController) {

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: titleButton, style: .default, handler: nil)
        alertController.addAction(action)
        viewController.present(alertController, animated: true)
    }

    ///Alert notification that requires user's input
    static func inputTextAlert(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addTextField { field in
            field.placeholder = "TICKER"
            field.clearButtonMode = .always
            field.autocorrectionType = .no
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.smartInsertDeleteType = .no
            field.spellCheckingType = .no
            field.keyboardType = .alphabet
            field.returnKeyType = .default
            field.keyboardType = .default
            field.autocapitalizationType = .allCharacters
        }
        return alert
    }
}
