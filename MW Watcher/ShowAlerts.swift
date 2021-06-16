//
//  ShowAlerts.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/16/21.
//

import UIKit

class ShowAlerts {
    static func showSimpleAlert(title: String?, message: String?, titleButton: String?, over viewController: UIViewController) {

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: titleButton, style: .default, handler: nil)
        alertController.addAction(action)
        viewController.present(alertController, animated: true)
    }

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


//func presentAlertwithYesNoPrompt(title: String, message: String, complete: @escaping (Bool) -> Void) {
//func presentAlert               (title: String, message: String, completion: @escaping (UIAlertAction) -> Void = {_ in }) {

//self.presentAlertWithYesNoPrompt(title: "Do you like cheese?", message: "We realize not everybody does") { (likesCheese) in
//    print(likesCheese)
//}


//extension UIViewController {
//    func showAlert(title: String, message: String, titleButton: String) {
//        let dialogMessage = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        let ok = UIAlertAction(title: titleButton, style: .default, handler: { (action) -> Void in
//            print("Ok button tapped")
//         })
//        dialogMessage.addAction(ok)
//        self.present(dialogMessage, animated: true, completion: nil)
//    }
//}


//enum PopoverAnchor {
//    case barButton(button: UIBarButtonItem)
//    case view(view: UIView)
//}
//And the method to present action sheet would look like this:
//
//static func showActionSheet(title: String, anchor: PopoverAnchor, over viewController: UIViewController) {
//    let ac = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
//
//    switch anchor {
//    case .barButton(let button):
//        ac.popoverPresentationController?.barButtonItem = button
//    case .view(let view):
//        ac.popoverPresentationController?.sourceView = view
//        ac.popoverPresentationController?.sourceRect = view.bounds
//    }
//
//    ac.addAction(.gotIt)
//
//    viewController.present(ac, animated: true)
//}
