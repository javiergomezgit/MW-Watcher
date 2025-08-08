//
//  MarketsViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/27/21.
//

import UIKit

class MarketsViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var currentPriceLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var arrowImageView: UIImageView!
    @IBOutlet weak var openChartButton: UIButton!
    @IBOutlet weak var stockBackgroundView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        openChartButton.setTitle("", for: .normal)
        //self.contentView.backgroundColor = UIColor(named: "customCellCollection")
    }
    
    
}




