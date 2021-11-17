//
//  CostCalculatorController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 11/13/21.
//

import UIKit

class CostCalculatorController: UIViewController {

    @IBOutlet weak var qtyOwnedText: UITextField!
    @IBOutlet weak var priceOwnedText: UITextField!
    @IBOutlet weak var amountOwnedText: UITextField!
    
    @IBOutlet weak var qtyBuyingText: UITextField!
    @IBOutlet weak var priceBuyingText: UITextField!
    @IBOutlet weak var amountBuyingText: UITextField!
    
    @IBOutlet weak var amountTotalLabel: UILabel!
    @IBOutlet weak var sharesTotalLabel: UILabel!
    @IBOutlet weak var profitLossPercentageLabel: UILabel!
    @IBOutlet weak var totalPriceLabel: UILabel!

    private var qtyOwned = 0
    private var priceOwned = 0.0
    private var amountOwned = 0.0
    private var totalAmountOwned = 0.0
    
    private var qtyBuying = 0
    private var priceBuying = 0.0
    private var amountBuying = 0.0
    private var totalAmountBuying = 0.0
    
    private var finalPrice = 0.0
    private var finalPercentage = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        qtyOwnedText.becomeFirstResponder()
    }
    
    @IBAction func qtyOwnedChanged(_ sender: Any) {
        totalOwned()
    }
    @IBAction func priceOwnedChanged(_ sender: Any) {
        totalOwned()
    }
    @IBAction func amountOwnedChanged(_ sender: Any) {
    }
        
    func totalOwned() {
        
        if !qtyOwnedText.text!.isEmpty {
            if let numberInt = Int(qtyOwnedText.text!) {
                self.qtyOwned = numberInt
            } else {
                let numDouble = Double(qtyOwnedText.text!)
                self.qtyOwned = Int(numDouble!)
            }
        } else { self.qtyOwned = 0 }
        
        
        if !priceOwnedText.text!.isEmpty {
            if let price = Double(priceOwnedText.text!) {
                self.priceOwned = price
            } else { self.priceOwned = 0.0 }
        }
        
        if !amountOwnedText.text!.isEmpty {
            if let amount = Double(amountOwnedText.text!) {
                self.amountOwned = amount
            } else { self.amountOwned = 0.0 }
        }
        
        totalAmountOwned = priceOwned * Double(qtyOwned)
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        let numberSting = formatter.string(from: totalAmountOwned as NSNumber)

        amountOwnedText.text = "$ \(numberSting!)"
        totalCost()
    }
    
    @IBAction func qtyBuyingChanged(_ sender: Any) {
        totalBuying()
    }
    @IBAction func priceBuyingChanged(_ sender: Any) {
        totalBuying()
    }
    
    func totalBuying() {
        if !qtyBuyingText.text!.isEmpty {
            if let numberInt = Int(qtyBuyingText.text!) {
                self.qtyBuying = numberInt
            } else {
                let numDouble = Double(qtyBuyingText.text!)
                self.qtyBuying = Int(numDouble!)
            }
        } else { self.qtyBuying = 0 }
        
        if !priceBuyingText.text!.isEmpty {
            if let price = Double(priceBuyingText.text!) {
                self.priceBuying = price
            } else { self.priceBuying = 0.0 }
        }
        
        if !amountBuyingText.text!.isEmpty {
            if let amount = Double(amountBuyingText.text!
            ) {
                self.amountBuying = amount
            } else { self.amountBuying = 0.0 }
        }
        
        totalAmountBuying = priceBuying * Double(qtyBuying)
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        let numberSting = formatter.string(from: totalAmountBuying as NSNumber)
        
        amountBuyingText.text = "$\(numberSting!)"
        totalCost()

    }
    
    func totalCost() {
        let totalAmounts = totalAmountOwned + totalAmountBuying
        let totalShares = qtyOwned + qtyBuying
        
        finalPrice = totalAmounts / Double(totalShares)
        
        
        finalPercentage = ((priceBuying * 100) / finalPrice) - 100

        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        formatter.numberStyle = .decimal
        //let numberSting = formatter.string(from: totalAmountBuying as NSNumber)
        
        let amountString = formatter.string(from: totalAmounts as NSNumber)
        amountTotalLabel.text = "S\(amountString!)"
        sharesTotalLabel.text = String(totalShares)
        
        if finalPercentage.isNaN {
            finalPercentage = 0
            finalPrice = 0
        }
        
        let totalPriceString = formatter.string(from: finalPrice as NSNumber)
        totalPriceLabel.text = "$\(totalPriceString!)"
        
        if finalPercentage < 0 {
            profitLossPercentageLabel.textColor = .red
        } else {
            profitLossPercentageLabel.textColor = .systemGreen
        }
        
        formatter.maximumFractionDigits = 2
        let finalPercentageString = formatter.string(from: finalPercentage as NSNumber)
        profitLossPercentageLabel.text = "\(finalPercentageString!)%"
        
    }
    
    

}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension String {
    var cleanNumber: String {
        let allowCharacters = Set("1234567890.")
        return self.filter {allowCharacters.contains($0) }
    }
}
