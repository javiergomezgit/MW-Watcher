//
//  ThesisStore.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

///Every thesis lives here, in Firestore only: `theses/{uid}/items/{watchlistID}_{ticker}`
///(BS-318). Nothing is kept on the device, so a reinstall or a second phone gets them back after
///signing in, and signing out leaves nothing behind. Signed out there are no theses: every call
///answers as if none exists.
///
///Firestore rules (in the console only) must let each person read and write only their own
///`theses/{uid}` subtree.
final class ThesisStore {

    // MARK: - Properties

    static let shared = ThesisStore()
    private init() {}

    ///What adding a stock found, so the screen knows whether to ask "Why are you watching it?".
    enum AddOutcome {
        ///No thesis yet: ask.
        case none
        ///One was archived when the stock left this list, and is active again.
        case restored(Thesis)
        ///Already active (added twice, or from another phone).
        case existing(Thesis)
        ///Signed out, or Firestore couldn't be read. Don't ask now.
        case unavailable
    }

    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    private func items(_ uid: String) -> CollectionReference {
        Firestore.firestore().collection("theses").document(uid).collection("items")
    }

    ///One document per stock per list. Tickers like "^GSPC" or "BRK-B" are valid ids; "/" never
    ///appears in a symbol.
    private func document(_ uid: String, ticker: String, watchlistID: String) -> DocumentReference {
        items(uid).document("\(watchlistID)_\(ticker.uppercased())")
    }

    // MARK: - Reading

    ///The active thesis for this stock on this list; nil when there is none, it's archived, or
    ///it can't be read. Calls back once, on the main queue.
    func thesis(ticker: String, watchlistID: String, completion: @escaping (Thesis?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(nil) }
        document(uid, ticker: ticker, watchlistID: watchlistID).getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Reading the thesis for \(ticker) failed: \(error.localizedDescription)")
            }
            let thesis = snapshot.flatMap(Self.thesis(from:))
            DispatchQueue.main.async { completion(thesis?.archived == false ? thesis : nil) }
        }
    }

    ///How many archived theses the account has, for the Settings row. nil when unreadable.
    func archivedCount(completion: @escaping (Int?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(0) }
        items(uid).whereField("archived", isEqualTo: true).getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Counting archived theses failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(snapshot?.documents.count ?? 0) }
        }
    }

    // MARK: - Writing

    ///Creates or replaces the thesis. Calls back once, on the main queue.
    func save(_ thesis: Thesis, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(nil) }
        var fields = Self.fields(of: thesis)
        fields["updatedAt"] = FieldValue.serverTimestamp()
        let reference = document(uid, ticker: thesis.ticker, watchlistID: thesis.watchlistID)
        reference.getDocument { snapshot, _ in
            //The first write stamps when it was written; later edits keep it.
            if snapshot?.exists != true { fields["createdAt"] = FieldValue.serverTimestamp() }
            reference.setData(fields, merge: true) { error in
                if let error = error as NSError? {
                    print("Saving the thesis for \(thesis.ticker) failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    ///Called by `SaveTickers` after a stock is added to a list. Restores an archived thesis
    ///(spec decision 6) and says whether there is one. Calls back once, on the main queue.
    func stockAdded(ticker: String, watchlistID: String, completion: @escaping (AddOutcome) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(.unavailable) }
        let reference = document(uid, ticker: ticker, watchlistID: watchlistID)
        reference.getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Reading the thesis for \(ticker) failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.unavailable) }
                return
            }
            guard var thesis = snapshot.flatMap(Self.thesis(from:)) else {
                DispatchQueue.main.async { completion(.none) }
                return
            }
            guard thesis.archived else {
                DispatchQueue.main.async { completion(.existing(thesis)) }
                return
            }
            thesis.archived = false
            reference.updateData(["archived": false, "updatedAt": FieldValue.serverTimestamp()]) { error in
                if let error = error as NSError? {
                    print("Restoring the thesis for \(ticker) failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { completion(.restored(thesis)) }
            }
        }
    }

    ///Called by `SaveTickers` after a stock leaves a list: its thesis is archived, not deleted.
    func stockRemoved(ticker: String, watchlistID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let reference = document(uid, ticker: ticker, watchlistID: watchlistID)
        reference.getDocument { snapshot, _ in
            guard snapshot?.exists == true else { return }
            reference.updateData(["archived": true, "updatedAt": FieldValue.serverTimestamp()]) { error in
                if let error = error as NSError? {
                    print("Archiving the thesis for \(ticker) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    ///Called by `WatchlistStore` after a whole list is deleted: every thesis on it is archived.
    func watchlistDeleted(id watchlistID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        items(uid).whereField("watchlistID", isEqualTo: watchlistID).getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Archiving a deleted list's theses failed: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else { return }
            let batch = Firestore.firestore().batch()
            for document in documents {
                batch.updateData(["archived": true, "updatedAt": FieldValue.serverTimestamp()], forDocument: document.reference)
            }
            batch.commit { error in
                if let error = error as NSError? {
                    print("Archiving a deleted list's theses failed: \(error.localizedDescription)")
                }
            }
        }
    }

    ///Settings' "Delete Archived Theses": permanently removes every archived one. Active theses
    ///are untouched. Calls back once, on the main queue, with how many went.
    func deleteArchived(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(.success(0)) }
        items(uid).whereField("archived", isEqualTo: true).getDocuments(source: .server) { snapshot, error in
            if let error = error as NSError? {
                print("Reading archived theses failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let documents = snapshot?.documents ?? []
            guard !documents.isEmpty else {
                DispatchQueue.main.async { completion(.success(0)) }
                return
            }
            //A batch holds 500 writes; nobody archives that many, but split anyway.
            let group = DispatchGroup()
            var firstError: Error?
            for start in stride(from: 0, to: documents.count, by: 500) {
                let batch = Firestore.firestore().batch()
                documents[start..<min(start + 500, documents.count)].forEach { batch.deleteDocument($0.reference) }
                group.enter()
                batch.commit { error in
                    if let error = error as NSError? {
                        print("Deleting archived theses failed: \(error.localizedDescription)")
                        firstError = firstError ?? error
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                if let firstError {
                    completion(.failure(firstError))
                } else {
                    completion(.success(documents.count))
                }
            }
        }
    }

    // MARK: - Mapping

    private static func fields(of thesis: Thesis) -> [String: Any] {
        [
            "ticker": thesis.ticker,
            "watchlistID": thesis.watchlistID,
            "reason": thesis.reason.rawValue,
            "note": String(thesis.note.prefix(Thesis.noteLimit)),
            "startDate": thesis.startDate,
            "startPrice": thesis.startPrice.map { $0 as Any } ?? NSNull(),
            "reconsider": [
                "trendBreak": thesis.reconsiderOnTrendBreak,
                "belowStart": thesis.reconsiderBelowStart.map { $0 as Any } ?? NSNull(),
                "belowHigh": thesis.reconsiderBelowHigh.map { $0 as Any } ?? NSNull()
            ],
            "archived": thesis.archived
        ]
    }

    ///nil for a document missing a field the app needs: an unknown reason is a newer app's
    ///thesis, which this one shouldn't overwrite with a guess.
    private static func thesis(from snapshot: DocumentSnapshot) -> Thesis? {
        guard let data = snapshot.data(),
              let ticker = data["ticker"] as? String,
              let watchlistID = data["watchlistID"] as? String,
              let reason = (data["reason"] as? String).flatMap(ThesisReason.init(rawValue:)),
              let startDate = data["startDate"] as? String else {
            if snapshot.exists { print("A thesis document (\(snapshot.documentID)) is missing fields") }
            return nil
        }
        let reconsider = data["reconsider"] as? [String: Any] ?? [:]
        return Thesis(ticker: ticker, watchlistID: watchlistID, reason: reason,
                      note: data["note"] as? String ?? "",
                      startDate: startDate,
                      startPrice: (data["startPrice"] as? NSNumber)?.doubleValue,
                      reconsiderOnTrendBreak: reconsider["trendBreak"] as? Bool ?? false,
                      reconsiderBelowStart: (reconsider["belowStart"] as? NSNumber)?.doubleValue,
                      reconsiderBelowHigh: (reconsider["belowHigh"] as? NSNumber)?.doubleValue,
                      archived: data["archived"] as? Bool ?? false)
    }
}
