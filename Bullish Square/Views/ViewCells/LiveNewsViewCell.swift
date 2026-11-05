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
    @IBOutlet weak var feedImageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var bottomView: UIView!
    ///Next to share; the controller sets what it posts. (BS-285)
    private(set) var communityButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        communityButton = PostToCommunity.addButton(before: shareButton)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        //feedImageView.roundCorners([.topLeft, .topRight], percent: 10)    // 10% rounded corners
        feedImageView.roundAllCorners(by: 10)
        bottomView.roundCornersUIView([.bottomLeft, .bottomRight], percent: 20)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    public func setNewsValues(headline: String, link: String, pubdate: String, author: String, imageFeed: UIImage) {
        headlineLabel.text = headline
        linkButton.titleLabel?.text = link
        pubdateLabel.text = pubdate
        feedImageView.image = imageFeed
        authorLabel.text = author
    }

}
