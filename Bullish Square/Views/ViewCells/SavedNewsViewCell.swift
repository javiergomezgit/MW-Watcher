//
//  HeadlineViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import AMPopTip

class SavedNewsViewCell: UITableViewCell {
    
    @IBOutlet weak var headlineLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var authorLabel: UILabel!
    
    @IBOutlet weak var linkButton: UIButton!
    
    @IBOutlet weak var imageNews: UIImageView!
    @IBOutlet weak var viewHeadline: UIView!
    @IBOutlet weak var viewImage: UIView!
    @IBOutlet weak var view: UIView!
    
    var popTip = PopTip()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        popTip.tapHandler = { popTip in
          print("tapped")
        }
        
        // Configure imageNews for rounded corners
        setupImageView()
        
        // Configure view for rounded top corners
        setupContainerView()
    }
    
    func setupImageView() {
            imageNews.layer.cornerRadius = 10.0
            imageNews.clipsToBounds = true // Clip content to rounded corners
    }
    
    func setupContainerView() {
        viewHeadline.layer.cornerRadius = 10.0 // Adjust for desired roundness
        viewHeadline.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        viewHeadline.clipsToBounds = true // Ensure content is clipped to rounded corners
        
        viewImage.layer.cornerRadius = 10.0
        viewImage.layer.maskedCorners = [ .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        viewImage.clipsToBounds = true
        
//        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    
    func showFirstTimeNotification(whereView: UIView) {
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX, y: 0, width: 100, height: 100)
        popTip.show(text: "Pass the news to others", direction: .left, maxWidth: 200, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
    }
    
    func showSecondTimeNotification(whereView: UIView) {
        popTip.arrowSize = CGSize(width: 40, height: 10)
        popTip.delayIn = TimeInterval(3)
        popTip.actionAnimation = .bounce(20)
        
        let positionPoptip = CGRect(x: 0, y: 0, width: 100, height: 100)
        popTip.show(text: "Swipe to delete", direction: .right, maxWidth: 120, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
