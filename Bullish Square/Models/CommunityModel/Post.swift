//
//  Post.swift
//  Bullish Square
//

import Foundation
import FirebaseFirestore

///One Community post, as stored at `posts/{id}`. (BS-265)
///
///The author is only a uid: names and photos are read from `profiles/{uid}` when shown, so a
///changed username or photo shows on old posts too. A reshare is a post of its own with no text
///and `reshareOf` naming the original.
struct Post: Hashable {

    // MARK: - Properties

    static let textMaximumLength = 500
    static let imageMaximumCount = 4
    static let tickerMaximumCount = 10

    let id: String
    let authorUid: String
    let text: String
    let imageURLs: [String]
    ///Storage paths of the images, so deleting the post can delete them.
    let imagePaths: [String]
    ///Upper-case symbols written as $AAPL in the text, in order, without repeats.
    let tickers: [String]
    let createdAt: Date
    var likeCount: Int
    var reshareCount: Int
    let reshareOf: String?
    let reshareOfAuthor: String?

    var isReshare: Bool { reshareOf != nil }

    // MARK: - Reading

    ///nil for a document missing what every post has.
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let authorUid = data["authorUid"] as? String,
              let text = data["text"] as? String else { return nil }
        id = document.documentID
        self.authorUid = authorUid
        self.text = text
        imageURLs = data["imageURLs"] as? [String] ?? []
        imagePaths = data["imagePaths"] as? [String] ?? []
        tickers = data["tickers"] as? [String] ?? []
        //A post just written locally has no server time yet; it sorts as now.
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        likeCount = data["likeCount"] as? Int ?? 0
        reshareCount = data["reshareCount"] as? Int ?? 0
        reshareOf = data["reshareOf"] as? String
        reshareOfAuthor = data["reshareOfAuthor"] as? String
    }

    init(id: String, authorUid: String, text: String, imageURLs: [String], imagePaths: [String],
         tickers: [String], createdAt: Date, reshareOf: String? = nil, reshareOfAuthor: String? = nil) {
        self.id = id
        self.authorUid = authorUid
        self.text = text
        self.imageURLs = imageURLs
        self.imagePaths = imagePaths
        self.tickers = tickers
        self.createdAt = createdAt
        self.likeCount = 0
        self.reshareCount = 0
        self.reshareOf = reshareOf
        self.reshareOfAuthor = reshareOfAuthor
    }

    // MARK: - Tickers

    ///"$aapl and $BRK.B" gives ["AAPL", "BRK.B"]: a dollar sign, one to five letters and an
    ///optional class letter. "$5" and "$100" are prices, not tickers, and are left alone.
    static func tickers(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\$([A-Za-z]{1,5}(?:\.[A-Za-z])?)\b"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var found: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let symbolRange = Range(match.range(at: 1), in: text) else { continue }
            let symbol = text[symbolRange].uppercased()
            if !found.contains(symbol) { found.append(symbol) }
            if found.count == tickerMaximumCount { break }
        }
        return found
    }
}
