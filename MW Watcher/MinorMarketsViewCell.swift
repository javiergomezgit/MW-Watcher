//
//  MinorMarketsViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/12/22.
//

import UIKit

class MinorMarketsViewCell: UITableViewCell {
    
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var nameCompanyLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet var currentPriceLabel: UILabel!
    @IBOutlet var arrowImageView: UIImageView!
    @IBOutlet weak var openChartButton: UIButton!
    @IBOutlet weak var imageCompanyImageView: UIImageView!
    @IBOutlet weak var frameCoverLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        openChartButton.setTitle("", for: .normal)
    }

}
