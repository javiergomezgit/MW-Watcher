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
            self.qtyOwned = Int(qtyOwnedText.text!) ?? 0
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
        amountOwnedText.text = "$ \(String(totalAmountOwned))"
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
            self.qtyBuying = Int(qtyBuyingText.text!) ?? 0
        } else { self.qtyBuying = 0 }
        
        if !priceBuyingText.text!.isEmpty {
            if let price = Double(priceBuyingText.text!) {
                self.priceBuying = price
            } else { self.priceBuying = 0.0 }
        }
        
        if !amountBuyingText.text!.isEmpty {
            if let amount = Double(amountBuyingText.text!) {
                self.amountBuying = amount
            } else { self.amountBuying = 0.0 }
        }
        
        totalAmountBuying = priceBuying * Double(qtyBuying)
        amountBuyingText.text = "$\(String(totalAmountBuying))"
        totalCost()

    }
    
    func totalCost() {
        let totalAmounts = totalAmountOwned + totalAmountBuying
        let totalShares = qtyOwned + qtyBuying
        
        finalPrice = totalAmounts / Double(totalShares)
        
        finalPercentage = ((finalPrice * 100) / priceOwned) - 100
    
        
        amountTotalLabel.text = "S\(String(totalAmounts))"
        sharesTotalLabel.text = String(totalShares)
        totalPriceLabel.text = "$\(String(finalPrice))" //-33
        
        if finalPercentage < 0 {
            profitLossPercentageLabel.textColor = .red
        } else {
            profitLossPercentageLabel.textColor = .systemGreen
        }
        
        profitLossPercentageLabel.text = "\(String(finalPercentage))%"
        
    }
    
    

}
