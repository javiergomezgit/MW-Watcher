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
    
    static func triggerNewsPrefetch() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = scene.delegate as? SceneDelegate {
            delegate.startNewsPrefetch()
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

        let categories = ["business", "world", "general"]
        let anyStale = categories.contains { NewsCache.shared.isStale($0) }
        if anyStale {
            startNewsPrefetch()
        }

        if MarketsCache.shared.isStale() {
            startMarketsPrefetch()
        }
    }
    
    // MARK: - News Prefetch
    
    func startNewsPrefetch() {
        let categories = ["business", "world", "general"]
        
        func fetchNext(_ index: Int) {
            guard index < categories.count else { return }
            let category = categories[index]
            
            DispatchQueue.global(qos: .background).async {
                NewsCallAPI.shared.loadAllNews(keySource: category) { items in
                    if let items = items {
                        NewsCache.shared.store(category: category, items: items)
                        print("✅ Cached: \(category) — \(items.count) articles from SceneDelegate ")
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                        fetchNext(index + 1)
                    }
                }
            }
        }
        fetchNext(0)
    }
    
    // MARK: - Markets Prefetch

    func startMarketsPrefetch() {
        ChartAPI.shared.getMajorMarketsValues(symbol: "^DJI") { result in
            guard case .success(let dji) = result else { return }
            ChartAPI.shared.getMajorMarketsValues(symbol: "^GSPC") { result in
                guard case .success(let sp500) = result else { return }
                ChartAPI.shared.getMajorMarketsValues(symbol: "^IXIC") { result in
                    guard case .success(let ixic) = result else { return }
                    StockAPI.shared.getPriceGeneralMarkets { markets, timestamp in
                        guard let markets = markets else { return }
                        CryptoAPI.shared.getAllCryptosData { cryptoResult in
                            guard case .success(let cryptoData) = cryptoResult else { return }
                            let cached = MarketsCache.CachedData(
                                chartDJI: dji,
                                chartSP500: sp500,
                                chartIXIC: ixic,
                                marketQuotes: markets,
                                cryptoData: cryptoData,
                                timestamp: timestamp
                            )
                            MarketsCache.shared.store(cached)
                            print("✅ Markets data cached")
                        }
                    }
                }
            }
        }
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
