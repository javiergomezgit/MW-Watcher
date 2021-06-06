//
//  AppDelegate.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData


@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        return true
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        
        if isFirstLaunch() {
                        
            let saveTickers = SaveMyTickers()
            let saveHeadlines = SaveHeadlines()
           
            let headlines = ["TLA 0.0% | TESLA FAILED OVERSEE ELON MUSK TWEET SEC ARGUED LETTERS", "BRJB 1.95% | MEATPACER JBS HIT BY CYBERATTACH AFFECTING NORTH AMERICA AUSTRALIAN", "AMZ -0.15% | AMAZON STOP TESTIN JOB APPLICANTS MARIJUANA BACKS FEDERAL LEGALIZATION", "TLA 0.0% | TESLA FAILED OVERSEE ELON MUSK TWEET SEC ARGUED LETTERS"]
            let tickers = ["AAPL", "AA", "TSLA", "MSFT"]
            
            for headline in headlines {
                _ = saveHeadlines.saveHeadlines(headline: headline, date: "May 10, 2020", link: "")
            }
            for ticker in tickers {
                saveTickers.saveTicker(ticker: ticker)
            }
        }
                
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    
    func isFirstLaunch() -> Bool {
        let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if (isFirstLaunch) {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
            UserDefaults.standard.synchronize()
        }
        return isFirstLaunch
    }
    

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
     
    }
}

