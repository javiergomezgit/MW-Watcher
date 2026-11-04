//
//  AppUpdateGate.swift
//  Bullish Square
//

import UIKit

///Blocks a version the server no longer supports until it is updated. (BS-233)
///
///Asks the server's /v1/app-config for `minimumVersion` whenever the app becomes active, and
///covers everything with UpdateRequiredController when the installed version is below it.
///Normally the minimum blocks nobody; it is raised (MINIMUM_APP_VERSION in Railway) only for
///a release that older versions can't run alongside.
///
///A check that fails - offline, server down, App Check refused - never starts a block: nobody
///is locked out by a network problem.
final class AppUpdateGate {

    // MARK: - Properties

    static let shared = AppUpdateGate()
    private init() {}

    static let appStoreURL = URL(string: "itms-apps://apps.apple.com/app/id1568502942")!

    ///Its own window above the app's, so it stays on top whatever the app swaps in as root:
    ///sign-in, onboarding or the tab bar.
    private var blockingWindow: UIWindow?
    private var isChecking = false

    private struct AppConfig: Decodable {
        let minimumVersion: String
    }

    // MARK: - Checking

    func check(in scene: UIWindowScene) {
        guard !isChecking,
              let installed = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        isChecking = true

        MarketDataServer.authorizedRequest(path: "/v1/app-config") { [weak self] result in
            guard case .success(let request) = result else {
                DispatchQueue.main.async { self?.isChecking = false }
                return
            }
            URLSession.shared.dataTask(with: request) { data, response, _ in
                var minimum: String?
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data {
                    minimum = (try? JSONDecoder().decode(AppConfig.self, from: data))?.minimumVersion
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isChecking = false
                    //Only an answer decides; no answer leaves things as they are.
                    guard let minimum else { return }
                    if Self.isVersion(installed, below: minimum) {
                        self.block(in: scene)
                    } else {
                        self.unblock(in: scene)
                    }
                }
            }.resume()
        }
    }

    ///"2.2" below "2.10", missing parts read as 0, so "2.3" equals "2.3.0". A version that
    ///isn't plain numbers is never below anything, so a malformed value can't block.
    static func isVersion(_ version: String, below minimum: String) -> Bool {
        func numbers(_ text: String) -> [Int]? {
            let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
            guard !parts.isEmpty, !parts.contains(nil) else { return nil }
            return parts.compactMap { $0 }
        }
        guard let installed = numbers(version), let required = numbers(minimum) else { return false }
        for index in 0..<max(installed.count, required.count) {
            let have = index < installed.count ? installed[index] : 0
            let need = index < required.count ? required[index] : 0
            if have != need { return have < need }
        }
        return false
    }

    // MARK: - Blocking

    private func block(in scene: UIWindowScene) {
        guard blockingWindow == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UpdateRequiredController()
        window.makeKeyAndVisible()
        blockingWindow = window
    }

    ///Hands the keyboard and taps back to the app's own window.
    private func unblock(in scene: UIWindowScene) {
        guard let window = blockingWindow else { return }
        window.isHidden = true
        blockingWindow = nil
        scene.windows.first { $0 !== window }?.makeKey()
    }
}
