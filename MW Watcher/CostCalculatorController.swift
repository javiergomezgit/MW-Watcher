//
//  CostCalculatorController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 11/13/21.
//

import UIKit

class CostCalculatorController: UIViewController {
    
    @IBOutlet weak var resetButton: UIButton!
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
        
        //        let imageButton = UIImage(systemName: "arrow.triangle.2.circlepath")
        //        resetButton.setImage(imageButton?.withRenderingMode(UIImage.RenderingMode.alwaysOriginal), for: .normal)
        //        resetButton.tintColor = .label
        //        resetButton.setTitleColor(.blue, for: .normal)
        //        resetButton.backgroundColor = .gray
        
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
            let numString = qtyOwnedText.text!.cleanNumber
            if let numberInt = Int(numString) {
                qtyOwned = numberInt
            } else {
                if let numberDouble = Double(numString) {
                    qtyOwned = Int(numberDouble)
                }
            }
        }
        
        if !priceOwnedText.text!.isEmpty {
            if let price = Double(priceOwnedText.text!.cleanNumber) {
                priceOwned = price
            }
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
            let numString = qtyBuyingText.text!.cleanNumber
            if let numberInt = Int(numString) {
                qtyBuying = numberInt
            } else {
                if let numDouble = Double(numString)
                {
                    qtyBuying = Int(numDouble)
                }
            }
        }
        
        if !priceBuyingText.text!.isEmpty {
            if let price = Double(priceBuyingText.text!.cleanNumber) {
                priceBuying = price
            }
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
    
    @IBAction func resetTextFields(_ sender: Any) {
        qtyOwnedText.text = ""
        qtyBuyingText.text = ""
        priceOwnedText.text = ""
        priceBuyingText.text = ""
        amountOwnedText.text = ""
        amountBuyingText.text = ""
        amountTotalLabel.text = ""
        sharesTotalLabel.text = ""
        profitLossPercentageLabel.text = ""
        totalPriceLabel.text = ""
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
