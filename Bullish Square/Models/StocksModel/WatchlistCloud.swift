//
//  WatchlistCloud.swift
//  Bullish Square
//
//  Created by Javier Gomez on 10/21/26.
//

import FirebaseFirestore
import Foundation

// MARK: - Shapes

///One account's watchlist as the cloud holds it. No logo bytes: they are re-fetchable and
///would bloat every document, so they stay in Core Data and an incoming ticker is refetched.
struct CloudWatchlist: Equatable {
    let id: String
    let name: String
    let order: Int
    let tickers: [CloudTicker]
}

struct CloudTicker: Equatable {
    let ticker: String
    let nameCompany: String
}

///Who keeps the account's watchlists, kept behind one interface so the backend can change, or
///a second one (Realtime Database) can serve other features, without touching the stores.
///
///Writes are fire-and-forget: the backend applies them locally at once - so the next
///`fetchAll` already sees them - queues them while offline, and reports failures itself.
///Only the read and account deletion hand a result back.
protocol WatchlistCloud {
    ///Every list and its tickers. `isConfirmed` is false when the answer came from a local
    ///cache rather than the server, which is not trusted enough to overwrite the device.
    func fetchAll(uid: String, completion: @escaping (Result<(lists: [CloudWatchlist], isConfirmed: Bool), Error>) -> Void)

    func saveWatchlist(uid: String, id: String, name: String, order: Int)
    func deleteWatchlist(uid: String, id: String)
    func addTicker(uid: String, watchlistID: String, ticker: CloudTicker)
    func removeTicker(uid: String, watchlistID: String, ticker: String)

    ///Account deletion. Reports failure, so the account is not deleted while its data survives.
    func deleteEverything(uid: String, completion: @escaping (Error?) -> Void)
}

// MARK: - Firestore

///Layout, shaped so per-ticker fields (notes, targets, alerts) are additive later:
///
///    users/{uid}/watchlists/{watchlistID}                    name, order, updatedAt
///    users/{uid}/watchlists/{watchlistID}/tickers/{ticker}    ticker, nameCompany, addedAt
///
///One document per ticker rather than an array on the list: adding one does not rewrite the
///whole list, and two phones adding different stocks at once do not overwrite each other.
final class FirestoreWatchlistCloud: WatchlistCloud {

    static let shared = FirestoreWatchlistCloud()

    private init() {}

    private func watchlists(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("watchlists")
    }

    private func tickers(uid: String, watchlistID: String) -> CollectionReference {
        watchlists(uid: uid).document(watchlistID).collection("tickers")
    }

    // MARK: Reads

    func fetchAll(uid: String, completion: @escaping (Result<(lists: [CloudWatchlist], isConfirmed: Bool), Error>) -> Void) {
        watchlists(uid: uid).getDocuments { snapshot, error in
            guard let snapshot else {
                completion(.failure(error ?? NSError(domain: "WatchlistCloud", code: -1)))
                return
            }

            var isConfirmed = !snapshot.metadata.isFromCache
            var lists = [CloudWatchlist]()
            var firstError: Error?
            let group = DispatchGroup()

            for document in snapshot.documents {
                let data = document.data()
                group.enter()
                document.reference.collection("tickers").getDocuments { tickerSnapshot, tickerError in
                    defer { group.leave() }
                    guard let tickerSnapshot else {
                        firstError = firstError ?? tickerError ?? NSError(domain: "WatchlistCloud", code: -2)
                        return
                    }
                    if tickerSnapshot.metadata.isFromCache { isConfirmed = false }

                    //A document with no symbol is skipped rather than defaulted: nothing else
                    //in the app can do anything with a ticker that has no symbol.
                    let entries: [CloudTicker] = tickerSnapshot.documents.compactMap { tickerDocument in
                        let tickerData = tickerDocument.data()
                        guard let ticker = tickerData["ticker"] as? String, !ticker.isEmpty else { return nil }
                        return CloudTicker(ticker: ticker, nameCompany: tickerData["nameCompany"] as? String ?? "n/a")
                    }

                    //A list touched only by addTicker has no name yet - see addTicker.
                    lists.append(CloudWatchlist(id: document.documentID,
                                                name: data["name"] as? String ?? WatchlistStore.defaultWatchlistName,
                                                order: data["order"] as? Int ?? 0,
                                                tickers: entries))
                }
            }

            //Firestore calls back on the main queue, so the appends above never race.
            group.notify(queue: .main) {
                if let firstError {
                    completion(.failure(firstError))
                } else {
                    completion(.success((lists: lists, isConfirmed: isConfirmed)))
                }
            }
        }
    }

    // MARK: Writes

    func saveWatchlist(uid: String, id: String, name: String, order: Int) {
        watchlists(uid: uid).document(id).setData([
            "name": name,
            "order": order,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error { print("Could not save watchlist \(id) to the cloud: \(error.localizedDescription)") }
        }
    }

    ///Firestore does not remove subcollections with their parent, so the tickers go first.
    func deleteWatchlist(uid: String, id: String) {
        let list = watchlists(uid: uid).document(id)
        list.collection("tickers").getDocuments { snapshot, error in
            if let error {
                print("Could not list watchlist \(id)'s tickers to delete: \(error.localizedDescription)")
            }
            let batch = Firestore.firestore().batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.deleteDocument(list)
            batch.commit { error in
                if let error { print("Could not delete watchlist \(id) from the cloud: \(error.localizedDescription)") }
            }
        }
    }

    ///Also touches the list's own document. A collection query only returns documents that
    ///exist, so a ticker under a list document that was never written would never be read
    ///back. Only `updatedAt` is written there, so a name set on another phone is kept.
    func addTicker(uid: String, watchlistID: String, ticker: CloudTicker) {
        let batch = Firestore.firestore().batch()
        batch.setData(["updatedAt": FieldValue.serverTimestamp()],
                      forDocument: watchlists(uid: uid).document(watchlistID), merge: true)
        batch.setData([
            "ticker": ticker.ticker,
            "nameCompany": ticker.nameCompany,
            "addedAt": FieldValue.serverTimestamp()
        ], forDocument: tickers(uid: uid, watchlistID: watchlistID).document(ticker.ticker), merge: true)
        batch.commit { error in
            if let error { print("Could not add \(ticker.ticker) to the cloud watchlist: \(error.localizedDescription)") }
        }
    }

    func removeTicker(uid: String, watchlistID: String, ticker: String) {
        tickers(uid: uid, watchlistID: watchlistID).document(ticker).delete { error in
            if let error { print("Could not remove \(ticker) from the cloud watchlist: \(error.localizedDescription)") }
        }
    }

    func deleteEverything(uid: String, completion: @escaping (Error?) -> Void) {
        watchlists(uid: uid).getDocuments(source: .server) { snapshot, error in
            guard let snapshot else {
                completion(error ?? NSError(domain: "WatchlistCloud", code: -3))
                return
            }

            var firstError: Error?
            let group = DispatchGroup()

            for document in snapshot.documents {
                group.enter()
                document.reference.collection("tickers").getDocuments(source: .server) { tickerSnapshot, tickerError in
                    guard let tickerSnapshot else {
                        firstError = firstError ?? tickerError ?? NSError(domain: "WatchlistCloud", code: -4)
                        group.leave()
                        return
                    }
                    let batch = Firestore.firestore().batch()
                    tickerSnapshot.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.deleteDocument(document.reference)
                    batch.commit { error in
                        if let error { firstError = firstError ?? error }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) { completion(firstError) }
        }
    }
}
