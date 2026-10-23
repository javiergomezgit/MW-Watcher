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
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var hasInitialFetchStarted = false
    
    ///`force` refetches every category, for pull to refresh.
    static func triggerNewsPrefetch(force: Bool = false) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = scene.delegate as? SceneDelegate {
            delegate.startNewsPrefetch(force: force)
        } else {
            //Nothing will run, but a pull to refresh is waiting to hear that it finished.
            NotificationCenter.default.post(name: NewsCache.prefetchDidFinish, object: nil)
        }
    }

    static func triggerMarketsPrefetch() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = scene.delegate as? SceneDelegate {
            delegate.startMarketsPrefetch()
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            addStarterTicker()
            logoutPossibleSessions()
            navigateToOnboardingController()
        } else {
            if UserDefaults.standard.bool(forKey: "userPrefersNoAccount") {
                navigateToMainController()
            } else if Auth.auth().currentUser != nil {
                navigateToMainController()
            } else {
                navigateToSignIn()
            }
        }
        
        // Start background prefetch for any navigation path
        startNewsPrefetch()
        startMarketsPrefetch()
        hasInitialFetchStarted = true
        
        window.makeKeyAndVisible()
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        guard hasInitialFetchStarted else { return }

        startNewsPrefetch()

        //Picks up what was changed on another phone meanwhile.
        WatchlistSyncService.shared.pull()

        startMarketsPrefetch()
    }
    
    // MARK: - News Prefetch
    
    ///Topics with a request out, so launch, foreground and pull to refresh never ask for the
    ///same one twice at once. Per topic, so switching chips mid-load never blocks the new one.
    ///Main thread only.
    private var newsTopicsInFlight: Set<String> = []

    ///Fetches the selected topic when it is older than five minutes, or always when `force`
    ///(pull to refresh). Only the chip on screen is fetched: the others load when picked.
    ///The saved feed counts, so a quick relaunch fetches nothing. Posts
    ///NewsCache.prefetchDidFinish with the topic when done, including when nothing was needed.
    func startNewsPrefetch(force: Bool = false) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.startNewsPrefetch(force: force) }
            return
        }

        let topic = NewsCache.shared.selectedTopic
        guard !newsTopicsInFlight.contains(topic) else { return }
        guard force || NewsCache.shared.isStale(topic) else {
            NotificationCenter.default.post(name: NewsCache.prefetchDidFinish, object: topic)
            return
        }
        newsTopicsInFlight.insert(topic)

        NewsCallAPI.shared.loadMarketNews(section: topic) { items in
            DispatchQueue.main.async {
                self.newsTopicsInFlight.remove(topic)
                if let items = items, !items.isEmpty {
                    NewsCache.shared.store(category: topic, items: items)
                }
                NotificationCenter.default.post(name: NewsCache.prefetchDidFinish, object: topic)
            }
        }
    }
    
    // MARK: - Markets Prefetch

    ///Fills MarketsCache in the background so the tab opens with data. A no-op when the
    ///saved copy is under five minutes old, which also spares the mboum quota.
    func startMarketsPrefetch() {
        MarketsCache.shared.refresh()
    }

    // MARK: - First Launch
    
    private func addStarterTicker() {
        guard let image = UIImage(named: "appleStock") else { return }
        
        let savedTickers = SaveTickers()
        let existing = savedTickers.loadTickers()
        
        // ✅ Fixed: only save if AAPL not already stored
        let alreadySaved = existing.contains { $0.ticker == "AAPL" }
        if !alreadySaved {
            let apple = TickersFeatures(ticker: "AAPL", nameTicker: "Apple Inc.", imageTicker: image, imageTickerName: "Apple Image")
            savedTickers.saveTicker(tickerFeatures: apple)
        }
        
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
    
    private func logoutPossibleSessions() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Sign-out failed: \(error.localizedDescription)")
        }
        
        if KeychainManager.deleteUID() {
            print("UID deleted from Keychain")
        } else {
            print("Keychain UID deletion failed")
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToSignIn() {
        let vc = UIStoryboard(name: "Login", bundle: nil)
            .instantiateViewController(withIdentifier: "SignInViewController")
        window?.rootViewController = vc
    }
    
    private func navigateToOnboardingController() {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "OnboardingController")
        window?.rootViewController = vc
    }
    
    private func navigateToMainController() {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "MarketWatcher")
        window?.rootViewController = vc
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
