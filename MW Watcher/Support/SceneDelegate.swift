//
//  SceneDelegate.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    // Store the Firebase auth state listener handle
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        
        
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            let imageCompany = UIImage(named: "appleStock")
            let tickerFeatures = TickersFeatures(ticker: "AAPL", nameTicker: "Apple Inc.", imageTicker: imageCompany!)
            let savedTickers = SaveTickers()
            savedTickers.saveTicker(tickerFeatures: tickerFeatures)
            
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let launchVC = storyboard.instantiateViewController(withIdentifier: "LaunchController")
            window.rootViewController = launchVC
        } else {
            
            //Listen for firebase auth state changes
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
                guard let self = self else { return }
                
                // Remove the listener to prevent multiple triggers
                if let handle = self.authStateHandle {
                    Auth.auth().removeStateDidChangeListener(handle)
                    self.authStateHandle = nil
                }
                
                if let user = user {
                    //User is logged in
                    print ("User logged \(user.uid)")
                    
                    //Save UID to keychain
                    if KeychainManager.saveUID(user.uid) {
                        print ("Saved UID to Keychain")
                    }
                    
                    if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        UserDefaults.standard.set(true, forKey: "signedInBefore")
                        
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let launchVC = storyboard.instantiateViewController(withIdentifier: "LaunchController")
                        window.rootViewController = launchVC
                    } else {
                        UserDefaults.standard.set(true, forKey: "signedInBefore")
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let mainTabBar = storyboard.instantiateInitialViewController()!
                        window.rootViewController = mainTabBar
                    }
                } else {
                    //No user logged in
                    let storyboard = UIStoryboard(name: "Login", bundle: nil)
                    let loginVC = storyboard.instantiateInitialViewController()!
                    window.rootViewController = loginVC
                }
            }
            
        }
        
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    
}
