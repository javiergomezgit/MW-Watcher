//
//  MyTickersViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit

class WatchlistViewCell: UITableViewCell {

    @IBOutlet var tickerLabel: UILabel!
    @IBOutlet var changeLabel: UILabel!
    @IBOutlet var currentPriceLabel: UILabel!
    @IBOutlet var previousPriceLabel: UILabel!
    @IBOutlet var imageArrow: UIImageView!
    @IBOutlet weak var buttonTickerNews: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
