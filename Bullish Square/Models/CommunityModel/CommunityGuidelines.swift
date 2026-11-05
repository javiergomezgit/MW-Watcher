//
//  CommunityGuidelines.swift
//  Bullish Square
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

///What App Store guideline 1.2 asks of an app where people post: terms everyone agrees to
///before posting, with no tolerance for objectionable content, and a filter for it. (BS-271)
///
///Acceptance is saved on the private account document, `users/{uid}.communityTermsAcceptedAt`,
///and the Firestore rules refuse a post without it, so an old or altered app can't skip it.
enum CommunityGuidelines {

    static let termsURL = "https://www.jdevit.com/terms-of-service-bullish-square/"

    static let text = """
    Bullish Square Community is for sharing market ideas with respect.

    By posting you agree to these rules. There is no tolerance for objectionable content or abusive users:

    • No hate speech, harassment, bullying or threats.
    • No sexual, violent or graphic content.
    • No spam, scams, pump-and-dump schemes or impersonation.
    • No sharing other people's private information.
    • Posts are opinions, not financial advice. Don't present them as guarantees.

    Report posts or accounts that break these rules from the "…" menu, and block anyone you don't want to see. Reported content is reviewed within 24 hours; content that breaks the rules is removed and the account that posted it may be banned.
    """

    // MARK: - Acceptance

    private static func cacheKey(_ uid: String) -> String { "communityTermsAccepted_\(uid)" }

    ///Remembered on this phone once read, so the account is asked only the first time.
    static func hasAccepted(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(false) }
        if UserDefaults.standard.bool(forKey: cacheKey(uid)) { return completion(true) }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
            let accepted = snapshot?.data()?["communityTermsAcceptedAt"] != nil
            if accepted { UserDefaults.standard.set(true, forKey: cacheKey(uid)) }
            DispatchQueue.main.async { completion(accepted) }
        }
    }

    static func accept(completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(CommunityStore.CommunityError.notSignedIn) }
        Firestore.firestore().collection("users").document(uid)
            .setData(["communityTermsAcceptedAt": FieldValue.serverTimestamp()], merge: true) { error in
                if let error = error as NSError? {
                    print("Saving the community terms acceptance failed: \(error.localizedDescription)")
                } else {
                    UserDefaults.standard.set(true, forKey: cacheKey(uid))
                }
                DispatchQueue.main.async { completion(error) }
            }
    }

    // MARK: - Filter

    ///Slurs and the strongest profanity. Matched as whole words, after common look-alike
    ///swaps (0 for o, 1 for i, $ for s...), so "class" or "Scunthorpe" pass but "sh1t" doesn't.
    private static let blockedWords: Set<String> = [
        //Words that are also names or ordinary uses (Dick, a cock, Nazi history) are left out.
        "fuck", "fucking", "fucker", "motherfucker", "shit", "bullshit", "cunt", "pussy",
        "bitch", "bastard", "whore", "slut", "asshole", "porn", "rape", "rapist",
        "nigger", "nigga", "faggot", "fag", "retard", "spic", "chink", "kike", "wetback", "tranny", "dyke",
        "kys"
    ]

    ///True when the text contains a blocked word.
    static func containsObjectionableLanguage(_ text: String) -> Bool {
        let swapped = text.lowercased().map { character -> Character in
            switch character {
            case "0": return "o"
            case "1", "!": return "i"
            case "3": return "e"
            case "4", "@": return "a"
            case "5", "$": return "s"
            case "7": return "t"
            default: return character
            }
        }
        let words = String(swapped).split { !$0.isLetter }.map(String.init)
        return words.contains { word in
            blockedWords.contains(word) || blockedWords.contains(word.hasSuffix("s") ? String(word.dropLast()) : word)
        }
    }
}
