//
//  Comment.swift
//  Bullish Square
//

import Foundation
import FirebaseFirestore

///One comment on a post, as stored at `comments/{id}`. (BS-273)
///
///Top-level rather than under the post, so account deletion finds a person's comments with
///one `authorUid` query and no collection-group index. `postAuthorUid` lets the post's
///author delete comments on their post, and lets the rules check both sides of a block.
struct Comment: Hashable {

    // MARK: - Properties

    static let textMaximumLength = 500

    let id: String
    let postId: String
    let postAuthorUid: String
    let authorUid: String
    let text: String
    ///Symbols written as $AAPL, as on a post.
    let tickers: [String]
    ///Who it answers, when Reply was used; they are told as well as the post's author.
    let replyToUid: String?
    let createdAt: Date

    // MARK: - Reading

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let postId = data["postId"] as? String,
              let postAuthorUid = data["postAuthorUid"] as? String,
              let authorUid = data["authorUid"] as? String,
              let text = data["text"] as? String else { return nil }
        id = document.documentID
        self.postId = postId
        self.postAuthorUid = postAuthorUid
        self.authorUid = authorUid
        self.text = text
        tickers = data["tickers"] as? [String] ?? []
        replyToUid = data["replyToUid"] as? String
        //A comment just written locally has no server time yet; it sorts as now.
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    init(id: String, postId: String, postAuthorUid: String, authorUid: String, text: String,
         replyToUid: String?, createdAt: Date) {
        self.id = id
        self.postId = postId
        self.postAuthorUid = postAuthorUid
        self.authorUid = authorUid
        self.text = text
        self.tickers = Post.tickers(in: text)
        self.replyToUid = replyToUid
        self.createdAt = createdAt
    }
}

///Something someone did to you in Community: a like, reshare, comment, reply or follow, as
///stored at `activity/{id}`. (BS-273)
///
///Written by the person who did it, right after the like or follow itself, and readable
///only by `recipientUid`. Likes, reshares and follows use a fixed id per person and post, so
///liking twice keeps one entry, and undoing removes it.
struct CommunityActivity: Hashable {

    enum Kind: String {
        case like, reshare, comment, reply, follow
    }

    let id: String
    let kind: Kind
    let actorUid: String
    let recipientUid: String
    ///The post it is about; nil for a follow.
    let postId: String?
    ///The start of the comment, for a comment or reply.
    let snippet: String?
    let createdAt: Date

    static let snippetLength = 80

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let kind = (data["type"] as? String).flatMap(Kind.init(rawValue:)),
              let actorUid = data["actorUid"] as? String,
              let recipientUid = data["recipientUid"] as? String else { return nil }
        id = document.documentID
        self.kind = kind
        self.actorUid = actorUid
        self.recipientUid = recipientUid
        postId = data["postId"] as? String
        snippet = data["snippet"] as? String
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    ///The fixed id for a like, reshare or follow; a comment's entry uses the comment's id.
    static func documentID(_ kind: Kind, actor: String, recipient: String, postId: String?) -> String {
        [kind.rawValue, actor, postId ?? recipient].joined(separator: "_")
    }
}
