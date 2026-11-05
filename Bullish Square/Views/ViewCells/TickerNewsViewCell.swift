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
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var shareButton: UIButton!
    ///Next to share; the controller sets what it posts. (BS-285)
    private(set) var communityButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        communityButton = PostToCommunity.addButton(before: shareButton)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        //feedImageView.roundCorners([.topLeft, .topRight], percent: 10)    // 10% rounded corners
        newsImageView.roundAllCorners(by: 10)
        bottomView.roundCornersUIView([.bottomLeft, .bottomRight], percent: 20)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
