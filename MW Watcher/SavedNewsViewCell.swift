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
    @IBOutlet var shareButton: UIButton!
    @IBOutlet var view: UIView!
    
    var popTip = PopTip()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        popTip.tapHandler = { popTip in
          print("tapped")
        }
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
