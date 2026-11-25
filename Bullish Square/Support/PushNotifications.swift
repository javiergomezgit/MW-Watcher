//
//  PushNotifications.swift
//  Bullish Square
//

import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

///Push notifications for Community activity: likes, reshares, comments, replies and new
///followers (BS-290), and trend alerts for watchlist stocks (BS-313, BS-314).
///
///The phone only registers and routes. It saves its APNs token under
///`users/{uid}/devices/{token}`, and the server, which watches `activity`, sends the
///notification through Apple directly. Which kinds a person wants live in `users/{uid}`
///under `notifications`, read by the server before sending.
///
///Permission is asked once, at a moment the person is already in Community (opening Activity,
///posting, commenting), never on first launch.
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {

    static let shared = PushNotifications()

    // MARK: - Properties

    ///The kinds a person can turn on or off, as the server reads them from
    ///`users/{uid}.notifications`.
    enum Kind: String, CaseIterable {
        case likes, comments, follows
        case trendBreak, backInUptrend

        static let community: [Kind] = [.likes, .comments, .follows]
        static let trends: [Kind] = [.trendBreak, .backInUptrend]

        var title: String {
            switch self {
            case .likes: return "Likes and Reshares"
            case .comments: return "Comments and Replies"
            case .follows: return "New Followers"
            case .trendBreak: return "Trend Breaks"
            case .backInUptrend: return "Back in Uptrend"
            }
        }

        ///Community activity is on until turned off. Trend alerts are off until turned on:
        ///a push about a price should never arrive unasked (BS-304).
        var defaultOn: Bool {
            Kind.community.contains(self)
        }
    }

    private static let askedKey = "pushPermissionAsked"
    private static let tokenKey = "pushDeviceToken"

    ///Debug builds from Xcode get sandbox tokens, TestFlight and the App Store production ones;
    ///the server sends each to the matching APNs host.
    #if DEBUG
    private static let environment = "sandbox"
    #else
    private static let environment = "production"
    #endif

    private var authHandle: AuthStateDidChangeListenerHandle?
    ///A tap that arrived before the tab bar was on screen, opened once it is.
    private var pendingRoute: [AnyHashable: Any]?

    private override init() {
        super.init()
    }

    // MARK: - Launch

    ///From `didFinishLaunching`: routes taps, refreshes the token when permission was given
    ///before, and saves it for whoever signs in later.
    func start() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard user != nil else { return }
            self?.saveToken()
        }
    }

    ///Asks once per install. A "Don't Allow" is not asked again; Settings → Notifications
    ///points to iOS Settings instead.
    func askIfNeeded() {
        guard Auth.auth().currentUser != nil, !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error as NSError? {
                print("Asking for notifications failed: \(error.localizedDescription)")
            }
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    ///Whether iOS lets the app show notifications, for the Settings screen.
    func isAllowed(completion: @escaping (Bool?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let allowed: Bool?
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: allowed = true
            case .denied: allowed = false
            default: allowed = nil
            }
            DispatchQueue.main.async { completion(allowed) }
        }
    }

    // MARK: - Token

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: Self.tokenKey)
        saveToken()
    }

    private func saveToken() {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        devices(uid).document(token).setData([
            "environment": Self.environment,
            "appVersion": version,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error as NSError? {
                print("Saving the notification token failed: \(error.localizedDescription)")
            }
        }
    }

    ///Before signing out, so the next person on this phone doesn't get the last one's
    ///notifications. Calls back once, also when there is nothing to remove or it fails.
    func forgetThisDevice(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return completion() }
        devices(uid).document(token).delete { error in
            if let error = error as NSError? {
                print("Removing the notification token failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion() }
        }
    }

    ///Every device of the account, for account deletion: Firestore keeps a document's
    ///subcollections when the document itself is deleted.
    func deleteAllDevices(uid: String, completion: @escaping (Error?) -> Void) {
        devices(uid).getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Reading the notification tokens failed: \(error.localizedDescription)")
                return DispatchQueue.main.async { completion(error) }
            }
            let batch = Firestore.firestore().batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { error in
                if let error = error as NSError? {
                    print("Deleting the notification tokens failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    private func devices(_ uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("devices")
    }

    // MARK: - Preferences

    ///Each kind's switch, with its default where nothing is stored. Calls back once, on the main
    ///queue. Read field by field: the map also holds the time zone, quiet hours and muted
    ///stocks, and reading it as `[String: Bool]` would turn every switch back to its default.
    func preferences(completion: @escaping ([Kind: Bool]) -> Void) {
        let defaults = Dictionary(uniqueKeysWithValues: Kind.allCases.map { ($0, $0.defaultOn) })
        guard let uid = Auth.auth().currentUser?.uid else { return completion(defaults) }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Reading notification settings failed: \(error.localizedDescription)")
            }
            let stored = snapshot?.data()?["notifications"] as? [String: Any] ?? [:]
            var result = defaults
            for kind in Kind.allCases {
                if let value = stored[kind.rawValue] as? Bool { result[kind] = value }
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    ///A trend switch also saves the phone's time zone, so the server keeps quiet hours
    ///(10 pm to 7 am) in local time.
    func setPreference(_ kind: Kind, on: Bool, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(nil) }
        var fields: [String: Any] = [kind.rawValue: on]
        if Kind.trends.contains(kind) {
            fields["timeZone"] = TimeZone.current.identifier
        }
        Firestore.firestore().collection("users").document(uid)
            .setData(["notifications": fields], merge: true) { error in
                if let error = error as NSError? {
                    print("Saving notification settings failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { completion(error) }
            }
    }

    // MARK: - Muted stocks

    ///Alerts and mutes belong to an account; signed out there's nothing to show.
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    ///Whether this stock's trend alerts are muted. False when signed out or unreadable.
    ///Calls back once, on the main queue.
    func isMuted(_ symbol: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(false) }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Reading muted stocks failed: \(error.localizedDescription)")
            }
            let stored = snapshot?.data()?["notifications"] as? [String: Any]
            let muted = (stored?["mutedSymbols"] as? [String] ?? []).map { $0.uppercased() }
            DispatchQueue.main.async { completion(muted.contains(symbol.uppercased())) }
        }
    }

    ///Adds or removes the stock in `notifications.mutedSymbols`, leaving the other stocks and
    ///switches as they are. Calls back once, on the main queue.
    func setMuted(_ symbol: String, muted: Bool, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(nil) }
        let change = muted ? FieldValue.arrayUnion([symbol.uppercased()]) : FieldValue.arrayRemove([symbol.uppercased()])
        Firestore.firestore().collection("users").document(uid)
            .setData(["notifications": ["mutedSymbols": change]], merge: true) { error in
                if let error = error as NSError? {
                    print("Saving a muted stock failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { completion(error) }
            }
    }

    // MARK: - UNUserNotificationCenterDelegate

    ///Shown as a banner even with the app open: the person may be on another tab.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            if !self.route(info) { self.pendingRoute = info }
            completionHandler()
        }
    }

    // MARK: - Routing

    ///Once the tab bar is on screen after a launch from a notification.
    func openPendingRoute() {
        guard let info = pendingRoute else { return }
        if route(info) { pendingRoute = nil }
    }

    ///A trend alert opens the stock in the Watchlist tab; a follow the follower's profile;
    ///anything else the post with its comments, in the Community tab. False when there is no
    ///tab bar yet.
    @discardableResult
    private func route(_ info: [AnyHashable: Any]) -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let tabs = scene.windows.first(where: \.isKeyWindow)?.rootViewController as? UITabBarController else { return false }
        if info["type"] as? String == "trend" {
            return routeTrend(info, tabs: tabs)
        }
        guard let index = tabs.viewControllers?.firstIndex(where: { $0 is CommunityNavigationController }),
              let navigation = tabs.viewControllers?[index] as? UINavigationController else { return false }
        tabs.selectedIndex = index
        navigation.dismiss(animated: false)
        if let postId = info["postId"] as? String {
            CommunityStore.shared.post(id: postId) { post in
                guard let post else {
                    return navigation.pushViewController(ActivityController(), animated: true)
                }
                navigation.pushViewController(CommentsController(post: post), animated: true)
            }
        } else if let actor = info["actorUid"] as? String {
            navigation.pushViewController(CommunityController(profileOf: actor), animated: true)
        } else {
            navigation.pushViewController(ActivityController(), animated: true)
        }
        return true
    }

    ///The stock's chart, scrolled to its Health card, where the trend and its explanation are.
    ///The thesis screen will take over when a thesis exists (BS-318). Opened like a search
    ///result: the chart loads its own price and logo.
    private func routeTrend(_ info: [AnyHashable: Any], tabs: UITabBarController) -> Bool {
        guard let symbol = info["symbol"] as? String,
              let index = tabs.viewControllers?.firstIndex(where: { ($0 as? UINavigationController)?.viewControllers.first is WatchlistController }),
              let navigation = tabs.viewControllers?[index] as? UINavigationController,
              let chart = ChartController.healthChart(symbol: symbol) else {
            return false
        }
        tabs.selectedIndex = index
        navigation.dismiss(animated: false)
        navigation.pushViewController(chart, animated: true)
        return true
    }
}
