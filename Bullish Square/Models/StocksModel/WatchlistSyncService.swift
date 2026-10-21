//
//  WatchlistSyncService.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/14/26.
//

import FirebaseAuth
import Foundation

///Keeps a signed-in user's watchlists in the cloud, so they survive a reinstall and match
///across phones. (BS-226)
///
///Core Data stays what every screen reads. Each change is written through to the cloud as it
///is made, and on sign-in, launch and return to the foreground the device's copy is replaced
///with the cloud's. The last write wins: a list or ticker removed on one phone goes from the
///others at their next sync.
///
///Signed out, nothing leaves the device. Signing in hands those lists to the account;
///signing out takes the account's lists off the device - the cloud still has them.
///
///The cloud itself sits behind `WatchlistCloud`, so this never names Firestore.
final class WatchlistSyncService {

    static let shared = WatchlistSyncService()

    private init() {}

    ///The list every install starts with. The one id two phones share by design; every other
    ///list id is a UUID made on the phone that created it.
    static let defaultWatchlistID = "default"

    ///Core Data scope for a signed-out user. Never sent to the cloud.
    static let localOwnerUID = "_local"

    ///Who the local cache currently belongs to.
    static var currentOwnerUID: String {
        Auth.auth().currentUser?.uid ?? localOwnerUID
    }

    static var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    ///Posted on the main queue when a sync changed the lists on the device.
    static let didChange = Notification.Name("WatchlistSyncService.didChange")

    private let cloud: WatchlistCloud = FirestoreWatchlistCloud.shared

    ///Everything below runs on the main queue: auth and Firestore call back there, and the
    ///stores use the view context.
    private var authHandle: AuthStateDidChangeListenerHandle?

    ///The account the device's lists belong to, as of the last auth change.
    private var syncedUID: String?

    private var isPulling = false
    private var pullAgain = false

    ///Bumped by every change written through, so a sync answer that left before one is not
    ///applied over it.
    private var localRevision = 0

    ///The lists carried into the account at sign-in were only the starter AAPL, which every
    ///install adds. Merged into an account that already has lists, it would come back on each
    ///new phone after being removed.
    private var carriedStarterOnly = false

    private func syncedKey(_ uid: String) -> String { "watchlistsSynced_\(uid)" }

    // MARK: - Lifecycle

    ///Once, at launch. Auth reports the restored user straight after, which starts the first sync.
    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [self] _, user in
            accountChanged(to: user?.uid)
        }
    }

    private func accountChanged(to uid: String?) {
        guard uid != syncedUID else { return }

        if let previous = syncedUID {
            signedOut(previous)
        }
        syncedUID = uid

        guard let uid else { return }
        signedIn(uid)
    }

    private func signedIn(_ uid: String) {
        let store = WatchlistStore.shared
        let signedOutLists = store.snapshot(ownerUID: Self.localOwnerUID)

        if !signedOutLists.isEmpty {
            carriedStarterOnly = signedOutLists.count == 1
                && signedOutLists[0].id == Self.defaultWatchlistID
                && signedOutLists[0].tickers.map(\.ticker) == ["AAPL"]
            store.reassign(fromOwner: Self.localOwnerUID, toOwner: uid)
            //The next sync merges instead of replacing, or the lists just handed over would
            //be replaced by the cloud's before they reached it.
            UserDefaults.standard.removeObject(forKey: syncedKey(uid))
        }

        pull()
    }

    private func signedOut(_ uid: String) {
        WatchlistStore.shared.removeLocal(ownerUID: uid)
        UserDefaults.standard.removeObject(forKey: syncedKey(uid))
        //Its tickers say which stocks the account watched.
        WatchlistPriceStore.shared.clear()
        carriedStarterOnly = false
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    // MARK: - Sync

    ///Replaces the device's lists with the cloud's. Safe to call any time: signed out it does
    ///nothing, and a call while one is running runs once more after it.
    func pull() {
        guard let uid = syncedUID else { return }
        guard !isPulling else {
            pullAgain = true
            return
        }
        isPulling = true
        let revision = localRevision

        cloud.fetchAll(uid: uid) { [self] result in
            isPulling = false
            defer {
                if pullAgain {
                    pullAgain = false
                    pull()
                }
            }

            //Signed out, or into another account, while the answer was out.
            guard uid == syncedUID else { return }
            //A change made meanwhile may be missing from the answer; ask again.
            guard revision == localRevision else {
                pullAgain = true
                return
            }

            switch result {
            case .failure(let error):
                print("Could not load the watchlists from the cloud; keeping the device's copy. \(error.localizedDescription)")
            case .success(let answer):
                //Offline, the answer is a cache that may be missing another phone's changes.
                //The next sync with a connection applies them.
                guard answer.isConfirmed else { return }
                apply(answer.lists, uid: uid)
            }
        }
    }

    private func apply(_ cloudLists: [CloudWatchlist], uid: String) {
        let store = WatchlistStore.shared
        var lists = cloudLists

        //An empty cloud is an account that never synced, never one that deleted everything:
        //the last list cannot be deleted. Either way the device's lists are merged up rather
        //than wiped.
        if !UserDefaults.standard.bool(forKey: syncedKey(uid)) || cloudLists.isEmpty {
            if !(carriedStarterOnly && !cloudLists.isEmpty) {
                lists = merge(store.snapshot(ownerUID: uid), into: cloudLists, uid: uid)
            }
            UserDefaults.standard.set(true, forKey: syncedKey(uid))
        }
        carriedStarterOnly = false

        let changed = store.replaceLocal(ownerUID: uid, with: lists)
        if lists.isEmpty {
            store.ensureDefaultExists()
        }
        if changed {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    ///Adds the device's lists and tickers the cloud lacks, writing each one up. A list the
    ///cloud already has keeps the cloud's name and order - another phone may have renamed it.
    private func merge(_ deviceLists: [CloudWatchlist], into cloudLists: [CloudWatchlist], uid: String) -> [CloudWatchlist] {
        var merged = cloudLists

        for deviceList in deviceLists {
            if let index = merged.firstIndex(where: { $0.id == deviceList.id }) {
                let cloudList = merged[index]
                let known = Set(cloudList.tickers.map(\.ticker))
                let missing = deviceList.tickers.filter { !known.contains($0.ticker) }
                guard !missing.isEmpty else { continue }

                missing.forEach { cloud.addTicker(uid: uid, watchlistID: cloudList.id, ticker: $0) }
                merged[index] = CloudWatchlist(id: cloudList.id, name: cloudList.name, order: cloudList.order,
                                               tickers: cloudList.tickers + missing)
            } else {
                cloud.saveWatchlist(uid: uid, id: deviceList.id, name: deviceList.name, order: deviceList.order)
                deviceList.tickers.forEach { cloud.addTicker(uid: uid, watchlistID: deviceList.id, ticker: $0) }
                merged.append(deviceList)
            }
        }
        return merged
    }

    // MARK: - Write-through

    ///The uid to write to, or nil when the change belongs to a signed-out user or to an
    ///account that is no longer the signed-in one.
    private func cloudUID(for ownerUID: String) -> String? {
        guard ownerUID != Self.localOwnerUID, ownerUID == Auth.auth().currentUser?.uid else { return nil }
        localRevision += 1
        return ownerUID
    }

    func watchlistSaved(_ watchlist: WatchlistStore.Watchlist, ownerUID: String) {
        guard let uid = cloudUID(for: ownerUID) else { return }
        cloud.saveWatchlist(uid: uid, id: watchlist.id, name: watchlist.name, order: watchlist.order)
    }

    func watchlistDeleted(id: String, ownerUID: String) {
        guard let uid = cloudUID(for: ownerUID) else { return }
        cloud.deleteWatchlist(uid: uid, id: id)
    }

    func tickerAdded(_ ticker: CloudTicker, watchlistID: String, ownerUID: String) {
        guard let uid = cloudUID(for: ownerUID) else { return }
        cloud.addTicker(uid: uid, watchlistID: watchlistID, ticker: ticker)
    }

    func tickerRemoved(_ ticker: String, watchlistID: String, ownerUID: String) {
        guard let uid = cloudUID(for: ownerUID) else { return }
        cloud.removeTicker(uid: uid, watchlistID: watchlistID, ticker: ticker)
    }

    // MARK: - Account deletion

    ///Must run while the user is still signed in: the security rules only let an account
    ///touch its own documents.
    func deleteCloudData(uid: String, completion: @escaping (Error?) -> Void) {
        cloud.deleteEverything(uid: uid, completion: completion)
    }
}
