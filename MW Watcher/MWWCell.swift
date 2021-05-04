//
//  MWWCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit

class MWWCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pubdateLabel: UILabel!
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var linkButton: UIButton!
    @IBOutlet weak var linkTickerButton: UIButton!
    @IBOutlet var imageViewFeed: UIImageView!
    
    static let identifier = "MWWCustomCell"
    
    static func nib() -> UINib {
        return UINib(nibName: "MWWCell", bundle: nil)
    }
    
    public func setRSSValues(title: String, description: String, link: String, pubdate: String, linkTicker: String, imageFeed: UIImage) {
        
        titleLabel.text = title
        linkButton.titleLabel?.text = link
        linkTickerButton.titleLabel?.text = linkTicker
        pubdateLabel.text = pubdate
        imageViewFeed.image = imageFeed

        isTickerPositive(tickerValue: description)
    }
    
    func isTickerPositive(tickerValue: String){
        tickerLabel.text = tickerValue
        if !tickerValue.isEmpty {
            if tickerValue.contains("-") {
                tickerLabel.textColor = UIColor.red
            } else {
                tickerLabel.textColor = UIColor.blue
            }
        }
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
