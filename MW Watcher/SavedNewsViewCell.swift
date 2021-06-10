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
        // Initialization code
    
//        let popTip = PopTip()
//        let positionPoptip = CGRect(x: headlineLabel.frame.maxX, y: 0, width: 100, height: 100)
//        popTip.show(text: "Make sure to share the most important news!", direction: .left, maxWidth: 200, in: view, from: positionPoptip)
//        
//        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
        
//        
////        let customView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
////        // Configure your view
////        popTip.show(customView: customView, direction: .up, in: view, from: tableView.frame)
//
//        //popTip.hide()
//        //popTip.show(text: "Hey! Listen!", direction: .up, maxWidth: 200, in: view, from: tableView.frame, duration: 3)
//
        //popTip.shouldDismissOnTap = true
        
        popTip.tapHandler = { popTip in
          print("tapped")
            //NO MORE new notification
        }
        
//        popTip.appearHandler = { popTip in
//          print("appeared")
//        }
//
//        popTip.dismissHandler = { popTip in
//          print("dismissed")
//        }
//
//        popTip.tapOutsideHandler = { _ in
//          print("tap outside")
//        }
//
//        popTip.swipeOutsideHandler = { _ in
//          print("swipe outside")
//        }
        
        
        
//        popTip.update(text: "New string")
//        popTip.update(attributedText: someAttributedString)
//        popTip.update(customView: someView)
        
//        let here = CGRect(x: 100, y: 100, width: 10, height: 10)
//        let there = CGRect(x: 400, y: 400, width: 10, height: 10)

//        popTip.show(text: "Hey! Listen more!", direction: .up, maxWidth: 200, in: view, from: here)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//          popTip.from = there
//        }
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
