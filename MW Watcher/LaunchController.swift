//
//  LaunchController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/2/21.
//

import UIKit
import SwiftyOnboard


class LaunchController: UIViewController {
        
    var swiftyOnboard: SwiftyOnboard!
    
    @IBOutlet var logoImage: UIImageView!
    
    override func viewWillAppear(_ animated: Bool) {
        //MARK: Change to FALSE for testing
        if launchedBefore() {
            //If launched then go to mmw news
            DispatchQueue.main.async {
                let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
                let nextViewController = storyBoard.instantiateViewController(withIdentifier: "MarketWatcher")
            
                nextViewController.modalPresentationStyle = .fullScreen
                nextViewController.modalTransitionStyle = .crossDissolve
                self.show(nextViewController, sender: self)
            }
        } else {
            self.logoImage.alpha = 0
            swiftyOnboard = SwiftyOnboard(frame: view.frame)
            view.addSubview(swiftyOnboard)
            swiftyOnboard.dataSource = self
            swiftyOnboard.delegate = self

            let imageCompany = UIImage(named: "appleStock")
            let tickerFeatures = TickersFeatures(ticker: "AAPL", nameTicker: "Apple Inc.", imageTicker: imageCompany!)
            let savedTickers = SaveTickers()
            savedTickers.saveTicker(tickerFeatures: tickerFeatures)
        }
    }
    
    func launchedBefore() -> Bool {
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingLaunch")
        UserDefaults.standard.set(true, forKey: "firstLaunchingLaunch")
        UserDefaults.standard.synchronize()
        
        //MARK: Change to false for testing
        if isFirstLaunch {
            return true
        } else {
            return false
        }
    }
    
    @objc func handleContinue(sender: UIButton) {
        let index = sender.tag
        swiftyOnboard?.goToPage(index: index + 1, animated: true)
        
        if index == 2 {
            let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            let nextViewController = storyBoard.instantiateViewController(withIdentifier: "MarketWatcher")
            
            nextViewController.modalPresentationStyle = .fullScreen
            nextViewController.modalTransitionStyle = .crossDissolve
            show(nextViewController, sender: self)
        }
    }
    
    @objc func handleSkip() {
        swiftyOnboard?.goToPage(index: 2, animated: true)
    }
}

extension LaunchController: SwiftyOnboardDataSource, SwiftyOnboardDelegate {
    
    func swiftyOnboardNumberOfPages(_ swiftyOnboard: SwiftyOnboard) -> Int {
            return 3
        }

    func swiftyOnboardPageForIndex(_ swiftyOnboard: SwiftyOnboard, index: Int) -> SwiftyOnboardPage? {

        let page = SwiftyOnboardPage()
        //TODO: Change original code of SwiftyOnboardPage to this:
        /*
         Changed original code of SwiftyOnboardPage
         let margin = self.layoutMarginsGuide
         imageView.translatesAutoresizingMaskIntoConstraints = false
         imageView.leftAnchor.constraint(equalTo: margin.leftAnchor, constant: 30).isActive = true
         imageView.rightAnchor.constraint(equalTo: margin.rightAnchor, constant: -5).isActive = true
         imageView.topAnchor.constraint(equalTo: margin.topAnchor, constant: 5).isActive = true
         imageView.heightAnchor.constraint(equalTo: margin.heightAnchor, multiplier: 0.8).isActive = true
         */
        
        page.subTitle.isHidden = true
        page.title.isHidden = true
        
//        page.title.font = UIFont(name: "Cochin", size: 22)
//        if index == 0 {
//            page.title.text = "description of text 1"
//        } else if index == 1 {
//            page.title.text = "description of text 2"
//        } else {
//            page.title.text = "description of text 3"
//        }
        
        page.backgroundColor = UIColor.white
        
        let nameOfImage = ("page\(index+1).jpg")
        page.imageView.image = UIImage(named: nameOfImage)
        
        return page
    }
    
    func swiftyOnboardViewForOverlay(_ swiftyOnboard: SwiftyOnboard) -> SwiftyOnboardOverlay? {
            let overlay = SwiftyOnboardOverlay()
            
            //Setup targets for the buttons on the overlay view:
            overlay.skipButton.addTarget(self, action: #selector(handleSkip), for: .touchUpInside)
            overlay.continueButton.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)
            
            //Setup for the overlay buttons:
            overlay.continueButton.titleLabel?.font = UIFont(name: "Lato-Bold", size: 20)
            overlay.continueButton.setTitleColor(UIColor.white, for: .normal)
            overlay.skipButton.setTitleColor(UIColor.white, for: .normal)
            overlay.skipButton.titleLabel?.font = UIFont(name: "Lato-Heavy", size: 20)
            
            //Return the overlay view:
            return overlay
        }
        
        func swiftyOnboardOverlayForPosition(_ swiftyOnboard: SwiftyOnboard, overlay: SwiftyOnboardOverlay, for position: Double) {
            let currentPage = round(position)
            overlay.pageControl.currentPage = Int(currentPage)
            print(Int(currentPage))
            overlay.continueButton.tag = Int(position)
            
            if currentPage == 0.0 || currentPage == 1.0 {
                overlay.continueButton.setTitle("Continue", for: .normal)
                overlay.skipButton.setTitle("Skip", for: .normal)
                overlay.skipButton.isHidden = false
            } else {
                overlay.continueButton.setTitle("Get Started!", for: .normal)
                overlay.skipButton.isHidden = true
            }
        }
    
   
}
