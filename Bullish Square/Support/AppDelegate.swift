//
//  AppDelegate.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import Firebase
import FirebaseAppCheck
import FirebaseCrashlytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var alreadyLaunched = false
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       
        //Before configure(), which is when Firebase reads it. Setting it afterwards is silently
        //ignored, and the market-data server would refuse every request.
        AppCheck.setAppCheckProviderFactory(BullishAppCheckProviderFactory())
        FirebaseApp.configure()
        print("🔍 Firebase SDK version: \(FirebaseApp.app()?.options.googleAppID ?? "unknown")")
        return true
    }
    
    ///A load failure used to crash here, so a failed migration or a corrupt file took the app
    ///down on every launch. PersistentStoreLoader recovers instead; see it for which failures
    ///replace the store and which leave it alone.
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SavingFeeds")
        
        let outcome = PersistentStoreLoader.load(container) { error, stage in
            print("Core Data store failed at \(stage). \(error), \(error.userInfo)")
            //Firebase is configured in didFinishLaunching and this container is lazy, so in
            //practice it is always ready. A missing report is not worth a crash if it is not.
            guard FirebaseApp.app() != nil else { return }
            Crashlytics.crashlytics().record(error: error, userInfo: ["stage": stage])
        }
        
        if outcome != .loaded {
            print("Core Data recovered from a load failure: \(outcome)")
        }
        return container
    }()
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
     
    }
}
