//
//  EmailSubscriptionStore.swift
//  Bullish Square
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

///The daily emails a user opted into, `emailSubscriptions/{uid}`. (BS-298)
///
///The server sends the watchlist email after each trading day's close to every account with
///`watchlist == true` and a verified address, which it reads from Firebase Auth: the app never
///sends or stores an email address. The email's unsubscribe link sets `watchlist` to false on
///the server, so the state is read from Firestore every time and never kept on the device.
final class EmailSubscriptionStore {

    // MARK: - Properties

    static let shared = EmailSubscriptionStore()
    private init() {}

    ///What a tap on the watchlist email button did.
    enum ToggleOutcome {
        case notSignedIn
        ///The server only emails verified addresses, so nothing was subscribed.
        case notVerified
        case changed(isOn: Bool)
    }

    private func document(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection("emailSubscriptions").document(uid)
    }

    // MARK: - Watchlist email

    ///Whether the signed-in account gets the watchlist email: false when signed out or never
    ///subscribed, nil when it could not be read, so the caller keeps what it shows.
    func isWatchlistOn(completion: @escaping (Bool?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        document(uid).getDocument { snapshot, error in
            if let error = error as NSError? {
                print("Reading the daily email setting failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let isOn = snapshot?.data()?["watchlist"] as? Bool ?? false
            DispatchQueue.main.async { completion(isOn) }
        }
    }

    ///Flips the watchlist email from what Firestore holds now, not from the icon: the email's
    ///unsubscribe link may have turned it off since the screen appeared. The account is
    ///reloaded first, so an address verified a minute ago in Mail counts.
    func toggleWatchlist(completion: @escaping (Result<ToggleOutcome, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.success(.notSignedIn))
            return
        }
        user.reload { [weak self] reloadError in
            if let reloadError = reloadError as NSError? {
                //Offline: the last known verification still decides.
                print("Refreshing the account failed: \(reloadError.localizedDescription)")
            }
            guard let self else {
                DispatchQueue.main.async { completion(.failure(CancellationError())) }
                return
            }
            guard (Auth.auth().currentUser ?? user).isEmailVerified else {
                DispatchQueue.main.async { completion(.success(.notVerified)) }
                return
            }
            let reference = self.document(user.uid)
            reference.getDocument { snapshot, readError in
                if let readError = readError as NSError? {
                    print("Reading the daily email setting failed: \(readError.localizedDescription)")
                    DispatchQueue.main.async { completion(.failure(readError)) }
                    return
                }
                let isOn = !(snapshot?.data()?["watchlist"] as? Bool ?? false)
                //Merged: a later news email shares this document.
                reference.setData(["watchlist": isOn, "updatedAt": FieldValue.serverTimestamp()],
                                  merge: true) { writeError in
                    if let writeError = writeError as NSError? {
                        print("Saving the daily email setting failed: \(writeError.localizedDescription)")
                        DispatchQueue.main.async { completion(.failure(writeError)) }
                        return
                    }
                    DispatchQueue.main.async { completion(.success(.changed(isOn: isOn))) }
                }
            }
        }
    }

    ///Sends the signed-in account the link that verifies its address.
    func resendVerificationEmail(completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        user.sendEmailVerification { error in
            if let error = error as NSError? {
                print("Sending the verification email failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion(error) }
        }
    }

    // MARK: - Account deletion

    ///Removes every subscription of a deleted account. Run while still signed in: the rules
    ///only let the owner delete it. A missing document deletes fine.
    func deleteSubscriptions(uid: String, completion: @escaping (Error?) -> Void) {
        document(uid).delete { error in
            if let error = error as NSError? {
                print("Deleting the daily email subscriptions failed: \(error.localizedDescription)")
            }
            completion(error)
        }
    }
}
