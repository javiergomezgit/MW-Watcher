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
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Handle first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            
            //Add apple ticker when app is new
            addStarterTicker()
            logoutPossibleSessions()
            
            //Got to onboarding screen
            navigateToLaunchController()
        } else {
            // Check if there's a current user cached locally
            if let _ = Auth.auth().currentUser  {
                self.navigateToMainController()
            } else {
                self.navigateToSignIn()
            }
        }
        
        window.makeKeyAndVisible()
    }
    
    // Save default ticker for first launch
    private func addStarterTicker() {
        if let image = UIImage(named: "appleStock") {
            let tickerFeatures = TickersFeatures(ticker: "AAPL", nameTicker: "Apple Inc.", imageTicker: image)
            let savedTickers = SaveTickers()
            savedTickers.saveTicker(tickerFeatures: tickerFeatures)
        }
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
    
    //If not found, then signout user
    private func logoutPossibleSessions() {
        do {
            try Auth.auth().signOut()
            if KeychainManager.deleteUID() {
                print("Successfully deleted UID from Keychain")
            } else {
                print("Failed to delete UID from Keychain")
            }
            navigateToSignIn()
        } catch {
            print("Local sign-out failed: \(error.localizedDescription)")
            if KeychainManager.deleteUID() {
                print("Successfully deleted UID from Keychain after sign-out failure")
            } else {
                print("Failed to delete UID from Keychain after sign-out failure")
            }
            //navigateToSignIn() // Navigate even if sign-out fails
        }
    }
    
    
    private func navigateToSignIn() {
        let storyboard = UIStoryboard(name: "Login", bundle: nil)
        let signInVC = storyboard.instantiateViewController(withIdentifier: "SignInViewController")
        window?.rootViewController = signInVC
    }
    
    private func navigateToLaunchController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let launchVC = storyboard.instantiateViewController(withIdentifier: "LaunchController")
        window?.rootViewController = launchVC
    }
    
    private func navigateToMainController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let launchVC = storyboard.instantiateViewController(withIdentifier: "MarketWatcher")
        window?.rootViewController = launchVC
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
