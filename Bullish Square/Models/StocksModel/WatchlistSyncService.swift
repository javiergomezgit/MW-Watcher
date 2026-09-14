//
//  WatchlistSyncService.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/14/26.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

///Firestore side of the watchlist.
///
///The watchlist used to live only in Core Data with no owner attached, so it survived
///sign-out and the next person to sign in on the device inherited it. Firestore is the system
///of record now; Core Data is that user's offline cache.
///
///Layout, shaped so multiple watchlists cost no migration later:
///
///    users/{uid}/watchlists/{watchlistID}                      name, order, createdAt
///    users/{uid}/watchlists/{watchlistID}/tickers/{ticker}      ticker, nameCompany, logoName, addedAt
///
///One document per ticker rather than an array on the watchlist document: no 1MB ceiling,
///adding or removing one ticker does not rewrite the whole list, and per-ticker fields
///(notes, target price, alerts) become additive rather than a reshape.
///
///Logo image bytes are deliberately **not** here. They are re-fetchable and would bloat every
///document, so Firestore keeps only the logo's name and the blob stays in Core Data.
final class WatchlistSyncService {

    static let shared = WatchlistSyncService()

    private init() {}

    ///v1 writes a single list under this id. Multiple watchlists later are simply more
    ///documents in the same collection.
    static let defaultWatchlistID = "default"

    ///Core Data scope for a signed-out user. Never sent to Firestore - it only keeps a
    ///signed-out person's rows from being read as a signed-in user's cache.
    static let localOwnerUID = "_local"

    ///Who the local cache currently belongs to.
    static var currentOwnerUID: String {
        Auth.auth().currentUser?.uid ?? localOwnerUID
    }

    static var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    // MARK: - Paths

    private func tickersCollection(uid: String, watchlistID: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("watchlists").document(watchlistID)
            .collection("tickers")
    }

    private func watchlistDocument(uid: String, watchlistID: String) -> DocumentReference {
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("watchlists").document(watchlistID)
    }

    // MARK: - Writes

    ///Creates the watchlist document if it is not there yet. Cheap, and it means the list has
    ///a name and an order before anything reads it.
    func ensureWatchlistExists(watchlistID: String = defaultWatchlistID,
                               name: String = "My Watchlist",
                               completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?()
            return
        }

        watchlistDocument(uid: uid, watchlistID: watchlistID).setData([
            "name": name,
            "order": 0,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                print("Could not create watchlist document: \(error.localizedDescription)")
            }
            completion?()
        }
    }

    ///Signed-out callers are a no-op rather than an error: the row still lands in Core Data
    ///under the local owner, and sign-in merges it up.
    func addTicker(_ ticker: String,
                   nameCompany: String,
                   logoName: String,
                   watchlistID: String = defaultWatchlistID,
                   completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(nil)
            return
        }

        tickersCollection(uid: uid, watchlistID: watchlistID).document(ticker).setData([
            "ticker": ticker,
            "nameCompany": nameCompany,
            "logoName": logoName,
            "addedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                print("Could not add \(ticker) to the remote watchlist: \(error.localizedDescription)")
            }
            completion?(error)
        }
    }

    func removeTicker(_ ticker: String,
                      watchlistID: String = defaultWatchlistID,
                      completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(nil)
            return
        }

        tickersCollection(uid: uid, watchlistID: watchlistID).document(ticker).delete { error in
            if let error {
                print("Could not remove \(ticker) from the remote watchlist: \(error.localizedDescription)")
            }
            completion?(error)
        }
    }

    ///Used by account deletion. Firestore does not remove subcollections when a parent
    ///document goes, so the tickers have to be deleted explicitly or they are orphaned.
    func deleteAllWatchlists(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion()
            return
        }

        let watchlists = Firestore.firestore()
            .collection("users").document(uid).collection("watchlists")

        watchlists.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                if let error { print("Could not list watchlists to delete: \(error.localizedDescription)") }
                completion()
                return
            }

            let group = DispatchGroup()

            for document in documents {
                group.enter()
                document.reference.collection("tickers").getDocuments { tickerSnapshot, _ in
                    let batch = Firestore.firestore().batch()
                    tickerSnapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.deleteDocument(document.reference)
                    batch.commit { _ in group.leave() }
                }
            }

            group.notify(queue: .main) { completion() }
        }
    }

    // MARK: - Reads

    struct RemoteTicker {
        let ticker: String
        let nameCompany: String
        let logoName: String
    }

    ///Signed-out callers get an empty list, never an error - there is simply nothing remote.
    func fetchTickers(watchlistID: String = defaultWatchlistID,
                      completion: @escaping (Result<[RemoteTicker], Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.success([]))
            return
        }

        tickersCollection(uid: uid, watchlistID: watchlistID).getDocuments { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            //A missing document is skipped rather than defaulted: a ticker with no symbol is
            //not something the rest of the app can do anything with.
            let tickers: [RemoteTicker] = (snapshot?.documents ?? []).compactMap { document in
                let data = document.data()
                guard let ticker = data["ticker"] as? String, !ticker.isEmpty else { return nil }
                return RemoteTicker(
                    ticker: ticker,
                    nameCompany: data["nameCompany"] as? String ?? "n/a",
                    logoName: data["logoName"] as? String ?? ""
                )
            }

            completion(.success(tickers))
        }
    }

    ///Pushes rows the device has but the account does not. Called on sign-in so a watchlist
    ///built before signing in is not thrown away.
    func pushLocalTickers(_ tickers: [(ticker: String, nameCompany: String, logoName: String)],
                          watchlistID: String = defaultWatchlistID,
                          completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !tickers.isEmpty else {
            completion()
            return
        }

        let collection = tickersCollection(uid: uid, watchlistID: watchlistID)
        let batch = Firestore.firestore().batch()

        for entry in tickers {
            batch.setData([
                "ticker": entry.ticker,
                "nameCompany": entry.nameCompany,
                "logoName": entry.logoName,
                "addedAt": FieldValue.serverTimestamp()
            ], forDocument: collection.document(entry.ticker), merge: true)
        }

        batch.commit { error in
            if let error {
                print("Could not push the local watchlist: \(error.localizedDescription)")
            }
            completion()
        }
    }
}
