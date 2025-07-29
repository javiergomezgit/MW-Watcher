//
//  TickerNewsViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/6/21.
//

import UIKit

class TickerNewsViewCell: UITableViewCell {

    @IBOutlet weak var headlineLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var linkButton: UIButton!
    @IBOutlet weak var newsImageView: UIImageView!
    @IBOutlet weak var authorLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
