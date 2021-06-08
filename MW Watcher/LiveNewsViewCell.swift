//
//  LiveNewsViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/7/21.
//

import UIKit

class LiveNewsViewCell: UITableViewCell {

    @IBOutlet weak var headlineLabel: UILabel!
    @IBOutlet weak var pubdateLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var linkButton: UIButton!
    @IBOutlet var imageViewFeed: UIImageView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    public func setNewsValues(headline: String, link: String, pubdate: String, author: String, imageFeed: UIImage) {
        
        headlineLabel.text = headline
        linkButton.titleLabel?.text = link
        pubdateLabel.text = pubdate
        imageViewFeed.image = imageFeed
        authorLabel.text = author
    }

}
