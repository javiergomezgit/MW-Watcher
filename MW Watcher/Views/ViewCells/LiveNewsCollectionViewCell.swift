//
//  LiveNewsCollectionViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 9/28/22.
//

import UIKit

class LiveNewsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var sourceLabel: UILabel!
    
    override func awakeFromNib() {
         super.awakeFromNib()
         
         contentView.translatesAutoresizingMaskIntoConstraints = false
         
         NSLayoutConstraint.activate([
             contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: 2),
             contentView.rightAnchor.constraint(equalTo: rightAnchor, constant: 2),
             contentView.topAnchor.constraint(equalTo: topAnchor),
             contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
         ])
        
        contentView.layer.cornerRadius = 15
    }
    
    override var isSelected: Bool {
        didSet{
            if self.isSelected {
                UIView.animate(withDuration: 0.3) { // for animation effect
                    self.contentView.backgroundColor = .systemOrange.withAlphaComponent(0.17)
                }
            }
            else {
                UIView.animate(withDuration: 0.3) { // for animation effect
                        self.contentView.backgroundColor = UIColor(red: 0/255, green: 199/255, blue: 190/255, alpha: 0.15)
                }
            }
        }
    }

    @IBOutlet private var maxWidthConstraint: NSLayoutConstraint! {
         didSet {
             maxWidthConstraint.isActive = false
         }
     }
     
     var maxWidth: CGFloat? = nil {
         didSet {
             guard let maxWidth = maxWidth else {
                 return
             }
             maxWidthConstraint.isActive = true
             maxWidthConstraint.constant = maxWidth
         }
     }
    
    public func setValues(source: String) {
        sourceLabel.text = source//.capitalized
    }
    
    public func colorSelectedSource(color: Bool) {
        if color {
            contentView.backgroundColor = .orange.withAlphaComponent(0.3)
        } else {
            if #available(iOS 15.0, *) {
                contentView.backgroundColor = .systemMint.withAlphaComponent(0.15)
            } else {
                // Fallback on earlier versions
            }
        }
    }
}
