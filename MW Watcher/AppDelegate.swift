//
//  AppDelegate.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import Firebase


@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var alreadyLaunched = false
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       
        FirebaseApp.configure()
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunching")
        UserDefaults.standard.set(true, forKey: "firstLaunching")
        UserDefaults.standard.synchronize()
        alreadyLaunched = isFirstLaunch

        print (alreadyLaunched)
        //Never launched before = false / NEW APP
        if !alreadyLaunched {
           saveFirstData()
            print ("enter to ssave initial data")
        }
        
        return true
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
                
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    //Saving initial data when new app
    func saveFirstData() {
        let saveHeadlines = UserSaveNews()
       
        let news = ["TLA 0.0% | TESLA FAILED OVERSEE ELON MUSK TWEET SEC ARGUED LETTERS", "BRJB 1.95% | MEATPACER JBS HIT BY CYBERATTACH AFFECTING NORTH AMERICA AUSTRALIAN", "AMZ -0.15% | AMAZON STOP TESTIN JOB APPLICANTS MARIJUANA BACKS FEDERAL LEGALIZATION", "TLA 0.0% | TESLA FAILED OVERSEE ELON MUSK TWEET SEC ARGUED LETTERS"]
        
        for new in news {
            _ = saveHeadlines.saveNews(headline: new, date: "May 10, 2020", link: "")
        }

    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
     
    }
}
