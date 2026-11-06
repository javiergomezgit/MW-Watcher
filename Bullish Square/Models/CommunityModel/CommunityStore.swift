//
//  CommunityStore.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

///Everything Community reads and writes: posts, follows, likes, reshares, comments, activity,
///blocks and reports. (BS-265, BS-273)
///
///Firestore layout - the rules (console) allow exactly these writes:
///- `posts/{postId}` and `posts/{postId}/likes/{uid}`, `posts/{postId}/reshares/{uid}`
///- `profiles/{uid}/following/{target}` with `profiles/{target}/followers/{uid}`, written together
///- `comments/{id}`, deletable by its author, the post's author and an admin
///- `activity/{id}`, written by who did it, read by who it is for
///- `blocks/{blocker}_{blocked}`, readable by both
///- `reports/{id}`, create only; an admin (token claim `admin`) reads and removes them
///Images live in Storage at `postImages/{uid}/{postId}/{n}.jpg`.
///
///Follower, following and post counts are counted when shown (Firestore `count()`), not kept
///as numbers someone has to keep right. Only a post's likes and reshares are stored as counts,
///and the rules let each move by one only alongside its own like or reshare document.
///
///Every completion is called exactly once, on the main queue.
final class CommunityStore {

    // MARK: - Properties

    static let shared = CommunityStore()
    private init() {}

    static let pageSize = 20
    ///Firestore's limit for an `in` query.
    private static let authorsPerQuery = 30
    ///Longest side of a posted photo; enough for a full-width card on a 3x phone.
    static let imageMaximumSide: CGFloat = 1600
    static let imageMaximumBytes = 2 * 1024 * 1024

    enum CommunityError: LocalizedError {
        case notSignedIn
        case tooLong
        case empty
        case unreadableImage

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Sign in to use Community."
            case .tooLong: return "Posts can be up to \(Post.textMaximumLength) characters."
            case .empty: return "Write something or add a photo."
            case .unreadableImage: return "One of the photos couldn't be read. Try another one."
            }
        }
    }

    ///A page of posts, newest first. `before` is passed back to get the next page; nil when
    ///there are no more.
    struct Page {
        let posts: [Post]
        let before: Date?
    }

    private var db: Firestore { Firestore.firestore() }
    private var posts: CollectionReference { db.collection("posts") }
    private var profiles: CollectionReference { db.collection("profiles") }
    private var blocks: CollectionReference { db.collection("blocks") }
    private var reports: CollectionReference { db.collection("reports") }
    private var comments: CollectionReference { db.collection("comments") }
    private var activity: CollectionReference { db.collection("activity") }

    var currentUid: String? { Auth.auth().currentUser?.uid }

    private func main<T>(_ completion: @escaping (T) -> Void) -> (T) -> Void {
        return { value in DispatchQueue.main.async { completion(value) } }
    }

    // MARK: - Feeds

    ///The latest posts from everyone.
    func discover(before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        newest(posts, before: before, feed: "the Discover feed", completion: completion)
    }

    ///The latest posts that mention `$symbol`, for a stock's chart. (BS-287)
    ///
    ///Needs the composite index `posts`: tickers (array-contains) + createdAt DESC. Until it
    ///exists Firestore refuses the query, and the printed error carries a link that creates it.
    func posts(aboutTicker symbol: String, before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        newest(posts.whereField("tickers", arrayContains: symbol.uppercased()), before: before,
               feed: "posts about \(symbol)", completion: completion)
    }

    private func newest(_ base: Query, before: Date?, feed: String, completion: @escaping (Result<Page, Error>) -> Void) {
        var query = base
        if let before { query = query.whereField("createdAt", isLessThan: Timestamp(date: before)) }
        query = query.order(by: "createdAt", descending: true).limit(to: Self.pageSize)
        let done = main(completion)
        query.getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Loading \(feed) failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            done(.success(Self.page(from: snapshot?.documents ?? [])))
        }
    }

    ///Posts by the people you follow. Your own are in Discover and on your profile, not here.
    func following(before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        guard let uid = currentUid else { return main(completion)(.failure(CommunityError.notSignedIn)) }
        followingUIDs(of: uid) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let uids):
                self.posts(by: uids, before: before, completion: completion)
            }
        }
    }

    ///One person's posts, for their profile.
    func posts(byUser uid: String, before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        posts(by: [uid], before: before, completion: completion)
    }

    ///Firestore takes 30 authors per `in` query, so a long following list is asked in groups
    ///and the answers merged. Each group's newest page is enough to know the overall newest.
    private func posts(by authors: [String], before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        let done = main(completion)
        let groups = stride(from: 0, to: authors.count, by: Self.authorsPerQuery).map {
            Array(authors[$0..<min($0 + Self.authorsPerQuery, authors.count)])
        }
        let group = DispatchGroup()
        let lock = NSLock()
        var documents: [QueryDocumentSnapshot] = []
        var failure: Error?
        for authors in groups {
            var query: Query = posts.whereField("authorUid", in: authors)
            if let before { query = query.whereField("createdAt", isLessThan: Timestamp(date: before)) }
            query = query.order(by: "createdAt", descending: true).limit(to: Self.pageSize)
            group.enter()
            query.getDocuments { snapshot, error in
                lock.lock()
                if let error { failure = error } else { documents += snapshot?.documents ?? [] }
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .global()) {
            if documents.isEmpty, let failure = failure as NSError? {
                print("Loading posts failed: \(failure.localizedDescription)")
                return done(.failure(failure))
            }
            done(.success(Self.page(from: documents)))
        }
    }

    private static func page(from documents: [QueryDocumentSnapshot]) -> Page {
        let sorted = documents.compactMap(Post.init(document:)).sorted { $0.createdAt > $1.createdAt }
        let page = Array(sorted.prefix(pageSize))
        return Page(posts: page, before: page.count == pageSize ? page.last?.createdAt : nil)
    }

    ///A single post, for a reshare's original. nil when it was deleted or can't be read.
    func post(id: String, completion: @escaping (Post?) -> Void) {
        let done = main(completion)
        posts.document(id).getDocument { snapshot, _ in
            done(snapshot.flatMap(Post.init(document:)))
        }
    }

    // MARK: - Posting

    ///Uploads the photos, then writes the post. Calls back with the post as the feed should
    ///show it.
    func createPost(text: String, images: [UIImage], completion: @escaping (Result<Post, Error>) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(.failure(CommunityError.notSignedIn)) }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= Post.textMaximumLength else { return done(.failure(CommunityError.tooLong)) }
        guard !text.isEmpty || !images.isEmpty else { return done(.failure(CommunityError.empty)) }
        let images = Array(images.prefix(Post.imageMaximumCount))
        let datas = images.compactMap(Self.jpegData)
        guard datas.count == images.count else { return done(.failure(CommunityError.unreadableImage)) }

        let document = posts.document()
        uploadImages(datas, uid: uid, postId: document.documentID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                done(.failure(error))
            case .success(let uploaded):
                let post = Post(id: document.documentID, authorUid: uid, text: text,
                                imageURLs: uploaded.map(\.url), imagePaths: uploaded.map(\.path),
                                tickers: Post.tickers(in: text), createdAt: Date())
                document.setData([
                    "authorUid": uid,
                    "text": post.text,
                    "imageURLs": post.imageURLs,
                    "imagePaths": post.imagePaths,
                    "tickers": post.tickers,
                    "createdAt": FieldValue.serverTimestamp(),
                    "likeCount": 0,
                    "reshareCount": 0
                ]) { error in
                    if let error = error as NSError? {
                        print("Saving the post failed: \(error.localizedDescription)")
                        self.deleteImages(paths: post.imagePaths)
                        return done(.failure(error))
                    }
                    done(.success(post))
                }
            }
        }
    }

    ///Uploads in order; the first failure removes what was uploaded and stops.
    private func uploadImages(_ datas: [Data], uid: String, postId: String,
                              completion: @escaping (Result<[(url: String, path: String)], Error>) -> Void) {
        var uploaded: [(url: String, path: String)] = []
        func next(_ index: Int) {
            guard index < datas.count else { return completion(.success(uploaded)) }
            let path = "postImages/\(uid)/\(postId)/\(index).jpg"
            let reference = Storage.storage().reference().child(path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            reference.putData(datas[index], metadata: metadata) { [weak self] _, error in
                if let error = error as NSError? {
                    print("Uploading a post photo failed: \(error.localizedDescription)")
                    self?.deleteImages(paths: uploaded.map(\.path))
                    return completion(.failure(error))
                }
                reference.downloadURL { url, error in
                    guard let url else {
                        self?.deleteImages(paths: uploaded.map(\.path) + [path])
                        return completion(.failure(error ?? CommunityError.unreadableImage))
                    }
                    uploaded.append((url.absoluteString, path))
                    next(index + 1)
                }
            }
        }
        next(0)
    }

    ///Scaled so the longest side is at most imageMaximumSide, keeping its shape, as JPEG under
    ///the Storage rule's 2 MB.
    static func jpegData(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, imageMaximumSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.8, 0.6, 0.4] as [CGFloat] {
            if let data = resized.jpegData(compressionQuality: quality), data.count < imageMaximumBytes { return data }
        }
        return nil
    }

    private func deleteImages(paths: [String]) {
        for path in paths {
            Storage.storage().reference().child(path).delete { _ in }
        }
    }

    ///Your own post, with its photos. A reshare also gives back its mark on the original.
    func deletePost(_ post: Post, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid, post.authorUid == uid else { return done(CommunityError.notSignedIn) }
        if let original = post.reshareOf {
            return removeReshare(postId: post.id, original: original, uid: uid, completion: completion)
        }
        posts.document(post.id).delete { [weak self] error in
            if let error = error as NSError? {
                print("Deleting the post failed: \(error.localizedDescription)")
                return done(error)
            }
            self?.deleteImages(paths: post.imagePaths)
            self?.deleteComments(onPost: post.id)
            done(nil)
        }
    }

    // MARK: - Likes

    func like(_ post: Post, completion: @escaping (Error?) -> Void) {
        setMark("likes", on: post.id, counter: "likeCount", marked: true) { [weak self] error in
            if error == nil { self?.recordActivity(.like, for: post.authorUid, postId: post.id) }
            completion(error)
        }
    }

    func unlike(_ post: Post, completion: @escaping (Error?) -> Void) {
        setMark("likes", on: post.id, counter: "likeCount", marked: false) { [weak self] error in
            if error == nil { self?.withdrawActivity(.like, recipient: post.authorUid, postId: post.id) }
            completion(error)
        }
    }

    ///Which of these posts you have liked.
    func likedPostIDs(_ ids: [String], completion: @escaping (Set<String>) -> Void) {
        markedPostIDs("likes", ids: ids, completion: completion)
    }

    ///The like document and the count move together, or neither does; the rules check that.
    private func setMark(_ collection: String, on postId: String, counter: String, marked: Bool,
                         completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(CommunityError.notSignedIn) }
        let post = posts.document(postId)
        let batch = db.batch()
        if marked {
            batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: post.collection(collection).document(uid))
        } else {
            batch.deleteDocument(post.collection(collection).document(uid))
        }
        batch.updateData([counter: FieldValue.increment(Int64(marked ? 1 : -1))], forDocument: post)
        batch.commit { error in
            if let error = error as NSError? {
                print("Updating \(collection) failed: \(error.localizedDescription)")
            }
            done(error)
        }
    }

    private func markedPostIDs(_ collection: String, ids: [String], completion: @escaping (Set<String>) -> Void) {
        let done = main(completion)
        guard let uid = currentUid, !ids.isEmpty else { return done([]) }
        let group = DispatchGroup()
        let lock = NSLock()
        var marked = Set<String>()
        for id in Set(ids) {
            group.enter()
            posts.document(id).collection(collection).document(uid).getDocument { snapshot, _ in
                if snapshot?.exists == true {
                    lock.lock(); marked.insert(id); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .global()) { done(marked) }
    }

    // MARK: - Reshares

    ///A post of your own pointing at the original, your mark on the original, and its count,
    ///in one batch. The mark holds the new post's id, so it can be undone.
    func reshare(_ original: Post, completion: @escaping (Result<Post, Error>) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(.failure(CommunityError.notSignedIn)) }
        let document = posts.document()
        let source = posts.document(original.id)
        let batch = db.batch()
        batch.setData([
            "authorUid": uid,
            "text": "",
            "imageURLs": [String](),
            "imagePaths": [String](),
            "tickers": [String](),
            "createdAt": FieldValue.serverTimestamp(),
            "likeCount": 0,
            "reshareCount": 0,
            "reshareOf": original.id,
            "reshareOfAuthor": original.authorUid
        ], forDocument: document)
        batch.setData(["postId": document.documentID, "createdAt": FieldValue.serverTimestamp()],
                      forDocument: source.collection("reshares").document(uid))
        batch.updateData(["reshareCount": FieldValue.increment(Int64(1))], forDocument: source)
        batch.commit { [weak self] error in
            if let error = error as NSError? {
                print("Resharing failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            self?.recordActivity(.reshare, for: original.authorUid, postId: original.id)
            done(.success(Post(id: document.documentID, authorUid: uid, text: "", imageURLs: [], imagePaths: [],
                               tickers: [], createdAt: Date(), reshareOf: original.id, reshareOfAuthor: original.authorUid)))
        }
    }

    ///Undoes your reshare of `original`.
    func unreshare(_ original: Post, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(CommunityError.notSignedIn) }
        posts.document(original.id).collection("reshares").document(uid).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            guard let postId = snapshot?.data()?["postId"] as? String else {
                return done(error)
            }
            self.removeReshare(postId: postId, original: original.id, uid: uid, completion: completion)
        }
    }

    func resharedPostIDs(_ ids: [String], completion: @escaping (Set<String>) -> Void) {
        markedPostIDs("reshares", ids: ids, completion: completion)
    }

    private func removeReshare(postId: String, original: String, uid: String, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        let source = posts.document(original)
        let batch = db.batch()
        batch.deleteDocument(posts.document(postId))
        batch.deleteDocument(source.collection("reshares").document(uid))
        batch.updateData(["reshareCount": FieldValue.increment(Int64(-1))], forDocument: source)
        withdrawActivity(.reshare, recipient: nil, postId: original)
        batch.commit { [weak self] error in
            guard let error = error as NSError? else {
                //A reshare has its own comments. (BS-292)
                self?.deleteComments(onPost: postId)
                return done(nil)
            }
            //The original may be gone; the reshare is still yours to delete.
            print("Undoing the reshare with its original failed, deleting it alone: \(error.localizedDescription)")
            self?.posts.document(postId).delete { error in
                if error == nil { self?.deleteComments(onPost: postId) }
                done(error)
            }
        }
    }

    // MARK: - Following

    ///Both halves of the follow, in one batch: your `following` entry and their `followers`
    ///entry. The rules refuse it if either of you has blocked the other.
    func follow(_ target: String, completion: @escaping (Error?) -> Void) {
        setFollow(target, following: true, completion: completion)
    }

    func unfollow(_ target: String, completion: @escaping (Error?) -> Void) {
        setFollow(target, following: false, completion: completion)
    }

    private func setFollow(_ target: String, following: Bool, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid, uid != target else { return done(CommunityError.notSignedIn) }
        let mine = profiles.document(uid).collection("following").document(target)
        let theirs = profiles.document(target).collection("followers").document(uid)
        let batch = db.batch()
        if following {
            let data: [String: Any] = ["createdAt": FieldValue.serverTimestamp()]
            batch.setData(data, forDocument: mine)
            batch.setData(data, forDocument: theirs)
        } else {
            batch.deleteDocument(mine)
            batch.deleteDocument(theirs)
        }
        batch.commit { [weak self] error in
            if let error = error as NSError? {
                print("Updating the follow failed: \(error.localizedDescription)")
            } else if following {
                self?.recordActivity(.follow, for: target, postId: nil)
            } else {
                self?.withdrawActivity(.follow, recipient: target, postId: nil)
            }
            done(error)
        }
    }

    func isFollowing(_ target: String, completion: @escaping (Bool) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(false) }
        profiles.document(uid).collection("following").document(target).getDocument { snapshot, _ in
            done(snapshot?.exists == true)
        }
    }

    ///Who `uid` follows, newest first, up to 500.
    func followingUIDs(of uid: String, completion: @escaping (Result<[String], Error>) -> Void) {
        edgeUIDs(profiles.document(uid).collection("following"), completion: completion)
    }

    ///Who follows `uid`, newest first, up to 500.
    func followerUIDs(of uid: String, completion: @escaping (Result<[String], Error>) -> Void) {
        edgeUIDs(profiles.document(uid).collection("followers"), completion: completion)
    }

    private func edgeUIDs(_ collection: CollectionReference, completion: @escaping (Result<[String], Error>) -> Void) {
        let done = main(completion)
        collection.order(by: "createdAt", descending: true).limit(to: 500).getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Loading follows failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            done(.success(snapshot?.documents.map(\.documentID) ?? []))
        }
    }

    struct Counts {
        var followers = 0
        var following = 0
        var posts = 0
    }

    ///Counted by Firestore when asked, about one read each. A count that fails reads 0.
    func counts(for uid: String, completion: @escaping (Counts) -> Void) {
        let done = main(completion)
        let group = DispatchGroup()
        let lock = NSLock()
        var counts = Counts()
        let queries: [(Query, WritableKeyPath<Counts, Int>)] = [
            (profiles.document(uid).collection("followers"), \.followers),
            (profiles.document(uid).collection("following"), \.following),
            (posts.whereField("authorUid", isEqualTo: uid), \.posts)
        ]
        for (query, field) in queries {
            group.enter()
            query.count.getAggregation(source: .server) { snapshot, error in
                if let error = error as NSError? {
                    print("Counting failed: \(error.localizedDescription)")
                }
                lock.lock(); counts[keyPath: field] = snapshot?.count.intValue ?? 0; lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .global()) { done(counts) }
    }

    // MARK: - Finding people

    ///Up to 20 accounts whose @username starts with `prefix` ("wol" finds @wolf_7908), as
    ///(handle, uid), alphabetical. Reads `usernames/{handle}` by document ID, so it needs no
    ///index. (BS-270)
    func searchUsernames(prefix: String, completion: @escaping ([(handle: String, uid: String)]) -> Void) {
        let done = main(completion)
        let handle = PublicProfileStore.normalized(prefix)
        guard !handle.isEmpty, handle.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }) else {
            return done([])
        }
        db.collection("usernames")
            .order(by: FieldPath.documentID())
            .start(at: [handle])
            .end(at: [handle + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error as NSError? {
                    print("Searching usernames failed: \(error.localizedDescription)")
                }
                done(snapshot?.documents.compactMap { document in
                    (document.data()["uid"] as? String).map { (document.documentID, $0) }
                } ?? [])
            }
    }

    // MARK: - Blocking

    ///Writes the block and removes the follows both ways. Their posts disappear from your
    ///feeds, yours from theirs, and the rules stop either of you following, liking or
    ///resharing the other.
    func block(_ target: String, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid, uid != target else { return done(CommunityError.notSignedIn) }
        let batch = db.batch()
        batch.setData(["blocker": uid, "blocked": target, "createdAt": FieldValue.serverTimestamp()],
                      forDocument: blocks.document("\(uid)_\(target)"))
        batch.deleteDocument(profiles.document(uid).collection("following").document(target))
        batch.deleteDocument(profiles.document(target).collection("followers").document(uid))
        batch.deleteDocument(profiles.document(target).collection("following").document(uid))
        batch.deleteDocument(profiles.document(uid).collection("followers").document(target))
        batch.commit { error in
            if let error = error as NSError? {
                print("Blocking failed: \(error.localizedDescription)")
            }
            done(error)
        }
    }

    func unblock(_ target: String, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(CommunityError.notSignedIn) }
        blocks.document("\(uid)_\(target)").delete { error in done(error) }
    }

    ///People you blocked (`blocked`) and people who blocked you (`blockedBy`). Both are hidden
    ///from you. Fails open to empty sets: a feed is shown rather than nothing.
    func blockLists(completion: @escaping (_ blocked: Set<String>, _ blockedBy: Set<String>) -> Void) {
        let done: (Set<String>, Set<String>) -> Void = { a, b in DispatchQueue.main.async { completion(a, b) } }
        guard let uid = currentUid else { return done([], []) }
        let group = DispatchGroup()
        var blocked = Set<String>()
        var blockedBy = Set<String>()
        group.enter()
        blocks.whereField("blocker", isEqualTo: uid).getDocuments { snapshot, _ in
            blocked = Set(snapshot?.documents.compactMap { $0.data()["blocked"] as? String } ?? [])
            group.leave()
        }
        group.enter()
        blocks.whereField("blocked", isEqualTo: uid).getDocuments { snapshot, _ in
            blockedBy = Set(snapshot?.documents.compactMap { $0.data()["blocker"] as? String } ?? [])
            group.leave()
        }
        group.notify(queue: .global()) { done(blocked, blockedBy) }
    }

    // MARK: - Comments (BS-273)

    static let commentsLimit = 200

    ///A post's comments, oldest first, like a conversation: the first 200.
    ///
    ///Needs the composite index `comments`: postId ASC + createdAt ASC. Until it exists the
    ///printed error carries a link that creates it.
    func comments(onPost postId: String, completion: @escaping (Result<[Comment], Error>) -> Void) {
        let done = main(completion)
        comments.whereField("postId", isEqualTo: postId)
            .order(by: "createdAt")
            .limit(to: Self.commentsLimit)
            .getDocuments { snapshot, error in
                if let error = error as NSError? {
                    print("Loading the comments failed: \(error.localizedDescription)")
                    return done(.failure(error))
                }
                done(.success(snapshot?.documents.compactMap(Comment.init(document:)) ?? []))
            }
    }

    ///A single comment, for a report. nil when it was deleted or can't be read.
    func comment(id: String, completion: @escaping (Comment?) -> Void) {
        let done = main(completion)
        comments.document(id).getDocument { snapshot, _ in
            done(snapshot.flatMap(Comment.init(document:)))
        }
    }

    ///How many comments each post has, counted by Firestore like follower counts. A count
    ///that fails is left out, so the button shows no number rather than a wrong one.
    func commentCounts(_ postIds: [String], completion: @escaping ([String: Int]) -> Void) {
        let done = main(completion)
        let group = DispatchGroup()
        let lock = NSLock()
        var counts: [String: Int] = [:]
        for id in Set(postIds) {
            group.enter()
            comments.whereField("postId", isEqualTo: id).count.getAggregation(source: .server) { snapshot, error in
                if let error = error as NSError? {
                    print("Counting comments failed: \(error.localizedDescription)")
                }
                if let count = snapshot?.count.intValue {
                    lock.lock(); counts[id] = count; lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .global()) { done(counts) }
    }

    ///Writes the comment, then tells the post's author and, for a reply, who was answered.
    ///The rules refuse it while either side has blocked the other.
    func addComment(_ text: String, to post: Post, replyingTo replyToUid: String?,
                    completion: @escaping (Result<Comment, Error>) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(.failure(CommunityError.notSignedIn)) }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return done(.failure(CommunityError.empty)) }
        guard text.count <= Comment.textMaximumLength else { return done(.failure(CommunityError.tooLong)) }
        let document = comments.document()
        let comment = Comment(id: document.documentID, postId: post.id, postAuthorUid: post.authorUid,
                              authorUid: uid, text: text, replyToUid: replyToUid, createdAt: Date())
        var data: [String: Any] = [
            "postId": post.id,
            "postAuthorUid": post.authorUid,
            "authorUid": uid,
            "text": text,
            "tickers": comment.tickers,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let replyToUid { data["replyToUid"] = replyToUid }
        document.setData(data) { [weak self] error in
            if let error = error as NSError? {
                print("Saving the comment failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            let snippet = String(text.prefix(CommunityActivity.snippetLength))
            self?.recordActivity(.comment, for: post.authorUid, postId: post.id, snippet: snippet, id: "comment_\(comment.id)")
            if let replyToUid, replyToUid != post.authorUid {
                self?.recordActivity(.reply, for: replyToUid, postId: post.id, snippet: snippet, id: "reply_\(comment.id)")
            }
            done(.success(comment))
        }
    }

    ///Your own comment, or any comment on your own post.
    func deleteComment(_ comment: Comment, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard currentUid != nil else { return done(CommunityError.notSignedIn) }
        comments.document(comment.id).delete { [weak self] error in
            if let error = error as NSError? {
                print("Deleting the comment failed: \(error.localizedDescription)")
                return done(error)
            }
            self?.activity.document("comment_\(comment.id)").delete { _ in }
            self?.activity.document("reply_\(comment.id)").delete { _ in }
            done(nil)
        }
    }

    ///After a post is deleted. Its author may delete every comment on it; best effort, as the
    ///comments are unreachable once the post is gone.
    private func deleteComments(onPost postId: String) {
        deleteMatches([comments.whereField("postId", isEqualTo: postId)]) { error in
            if let error = error as NSError? {
                print("Deleting a deleted post's comments failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Activity (BS-273)

    ///Tells `recipient` what you did. Best effort: the like or follow has already happened,
    ///and a lost entry only means one fewer line in their Activity.
    private func recordActivity(_ kind: CommunityActivity.Kind, for recipient: String, postId: String?,
                                snippet: String? = nil, id: String? = nil) {
        guard let uid = currentUid, uid != recipient else { return }
        var data: [String: Any] = [
            "type": kind.rawValue,
            "actorUid": uid,
            "recipientUid": recipient,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let postId { data["postId"] = postId }
        if let snippet { data["snippet"] = snippet }
        let documentID = id ?? CommunityActivity.documentID(kind, actor: uid, recipient: recipient, postId: postId)
        activity.document(documentID).setData(data) { error in
            if let error = error as NSError? {
                print("Recording \(kind.rawValue) activity failed: \(error.localizedDescription)")
            }
        }
    }

    ///Removes the entry when the like, reshare or follow is undone. `recipient` is only needed
    ///for a follow, whose id has no post.
    private func withdrawActivity(_ kind: CommunityActivity.Kind, recipient: String?, postId: String?) {
        guard let uid = currentUid, let recipient = recipient ?? postId else { return }
        activity.document(CommunityActivity.documentID(kind, actor: uid, recipient: recipient, postId: postId)).delete { _ in }
    }

    ///What happened to you lately, newest first: the last 100.
    ///
    ///Needs the composite index `activity`: recipientUid ASC + createdAt DESC.
    func recentActivity(completion: @escaping (Result<[CommunityActivity], Error>) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(.failure(CommunityError.notSignedIn)) }
        activity.whereField("recipientUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments { snapshot, error in
                if let error = error as NSError? {
                    print("Loading activity failed: \(error.localizedDescription)")
                    return done(.failure(error))
                }
                done(.success(snapshot?.documents.compactMap(CommunityActivity.init(document:)) ?? []))
            }
    }

    ///When the newest entry arrived, for the dot on the bell; nil when there is none.
    func newestActivityDate(completion: @escaping (Date?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(nil) }
        activity.whereField("recipientUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                done(snapshot?.documents.first.flatMap(CommunityActivity.init(document:))?.createdAt)
            }
    }

    // MARK: - Moderation (BS-273)

    ///One report, for the admin's Reports screen.
    struct Report {
        let id: String
        let reporterUid: String
        let userUid: String
        let postId: String?
        let commentId: String?
        let reason: ReportReason?
        let createdAt: Date
    }

    ///Whether this account may moderate: the `admin` claim on its token, set on the server
    ///with `npm run set-admin`. Refreshed, so a newly granted claim shows without signing out.
    func isAdmin(completion: @escaping (Bool) -> Void) {
        let done = main(completion)
        guard let user = Auth.auth().currentUser else { return done(false) }
        user.getIDTokenResult(forcingRefresh: true) { result, _ in
            done(result?.claims["admin"] as? Bool == true)
        }
    }

    ///Open reports, newest first. Only an admin may read them.
    func openReports(completion: @escaping (Result<[Report], Error>) -> Void) {
        let done = main(completion)
        reports.order(by: "createdAt", descending: true).limit(to: 100).getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Loading reports failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            done(.success(snapshot?.documents.compactMap { document in
                let data = document.data()
                guard let reporter = data["reporterUid"] as? String, let user = data["userUid"] as? String else { return nil }
                return Report(id: document.documentID, reporterUid: reporter, userUid: user,
                              postId: data["postId"] as? String, commentId: data["commentId"] as? String,
                              reason: (data["reason"] as? String).flatMap(ReportReason.init(rawValue:)),
                              createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
            } ?? []))
        }
    }

    ///Closes a report without action.
    func dismissReport(_ report: Report, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        reports.document(report.id).delete { error in
            if let error = error as NSError? {
                print("Dismissing the report failed: \(error.localizedDescription)")
            }
            done(error)
        }
    }

    ///Removes what was reported - the comment, or the post with its photos and comments - and
    ///closes the report. The rules let an admin delete anyone's post or comment.
    func removeReportedContent(_ report: Report, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        let closeReport: (Error?) -> Void = { [weak self] error in
            guard let self else { return done(error) }
            if let error { return done(error) }
            self.reports.document(report.id).delete { error in done(error) }
        }
        if let commentId = report.commentId {
            return comments.document(commentId).delete { error in closeReport(error) }
        }
        guard let postId = report.postId else { return done(nil) }
        posts.document(postId).getDocument { [weak self] snapshot, error in
            guard let self else { return done(nil) }
            //Already gone: only the report is left to close.
            guard let post = snapshot.flatMap(Post.init(document:)) else { return closeReport(error) }
            self.posts.document(postId).delete { error in
                if error == nil {
                    self.deleteImages(paths: post.imagePaths)
                    self.deleteComments(onPost: postId)
                }
                closeReport(error)
            }
        }
    }

    // MARK: - Account deletion

    ///Everything Community holds for `uid`, for account deletion (BS-272): their posts and
    ///photos, reshares (with the originals' counts), follows both ways, the blocks they
    ///made, their comments, and activity they caused or received (BS-273). Calls back once
    ///with the first error, or nil.
    ///
    ///Not removed: their likes on other people's posts, which hold only a uid and are counted
    ///in those posts, and blocks other people made of them, which belong to those people.
    func deleteAllCommunityData(uid: String, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        deleteAllPosts(uid: uid) { [weak self] error in
            guard let self else { return }
            if let error { return done(error) }
            self.deleteAllFollows(uid: uid) { error in
                if let error { return done(error) }
                let owned: [Query] = [
                    self.blocks.whereField("blocker", isEqualTo: uid),
                    self.comments.whereField("authorUid", isEqualTo: uid),
                    self.activity.whereField("actorUid", isEqualTo: uid),
                    self.activity.whereField("recipientUid", isEqualTo: uid)
                ]
                self.deleteMatches(owned, completion: done)
            }
        }
    }

    private func deleteAllPosts(uid: String, completion: @escaping (Error?) -> Void) {
        posts.whereField("authorUid", isEqualTo: uid).getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error { return completion(error) }
            let all = snapshot?.documents.compactMap(Post.init(document:)) ?? []
            let group = DispatchGroup()
            let lock = NSLock()
            var firstError: Error?
            for post in all {
                group.enter()
                let finished: (Error?) -> Void = { error in
                    lock.lock(); if firstError == nil { firstError = error }; lock.unlock()
                    group.leave()
                }
                if let original = post.reshareOf {
                    self.removeReshare(postId: post.id, original: original, uid: uid, completion: finished)
                } else {
                    self.posts.document(post.id).delete { error in
                        if error == nil { self.deleteImages(paths: post.imagePaths) }
                        finished(error)
                    }
                }
            }
            group.notify(queue: .global()) { completion(firstError) }
        }
    }

    ///Both halves of every follow, theirs and the other person's. The rules let either side
    ///remove a follow.
    private func deleteAllFollows(uid: String, completion: @escaping (Error?) -> Void) {
        let profile = profiles.document(uid)
        let group = DispatchGroup()
        let lock = NSLock()
        var references: [DocumentReference] = []
        var firstError: Error?
        for (mine, theirs) in [("following", "followers"), ("followers", "following")] {
            group.enter()
            profile.collection(mine).getDocuments { [weak self] snapshot, error in
                guard let self else { return group.leave() }
                lock.lock()
                if let error, firstError == nil { firstError = error }
                for document in snapshot?.documents ?? [] {
                    references.append(document.reference)
                    references.append(self.profiles.document(document.documentID).collection(theirs).document(uid))
                }
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .global()) { [weak self] in
            if let firstError { return completion(firstError) }
            self?.deleteDocuments(references, completion: completion)
        }
    }

    ///Every document the queries find, one query after another; stops at the first error.
    private func deleteMatches(_ queries: [Query], completion: @escaping (Error?) -> Void) {
        guard let query = queries.first else { return completion(nil) }
        query.getDocuments { [weak self] snapshot, error in
            guard let self else { return completion(nil) }
            if let error { return completion(error) }
            self.deleteDocuments(snapshot?.documents.map(\.reference) ?? []) { error in
                if let error { return completion(error) }
                self.deleteMatches(Array(queries.dropFirst()), completion: completion)
            }
        }
    }

    ///In batches of 400, under Firestore's 500 writes a batch.
    private func deleteDocuments(_ references: [DocumentReference], completion: @escaping (Error?) -> Void) {
        guard !references.isEmpty else { return completion(nil) }
        let chunk = Array(references.prefix(400))
        let batch = db.batch()
        chunk.forEach { batch.deleteDocument($0) }
        batch.commit { [weak self] error in
            if let error { return completion(error) }
            self?.deleteDocuments(Array(references.dropFirst(400)), completion: completion)
        }
    }

    // MARK: - Reporting

    enum ReportReason: String, CaseIterable {
        case spam, harassment, hate, sexual, violence, scam, other

        var title: String {
            switch self {
            case .spam: return "Spam"
            case .harassment: return "Harassment or bullying"
            case .hate: return "Hate speech"
            case .sexual: return "Sexual content"
            case .violence: return "Violence or threats"
            case .scam: return "Scam or fraud"
            case .other: return "Something else"
            }
        }
    }

    ///A post (with its author), a comment, or a profile. Reviewed in the app's Reports screen
    ///by an admin (BS-273), or in the Firebase console.
    func report(postId: String?, commentId: String? = nil, userUid: String, reason: ReportReason,
                completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(CommunityError.notSignedIn) }
        var data: [String: Any] = [
            "reporterUid": uid,
            "userUid": userUid,
            "reason": reason.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let postId { data["postId"] = postId }
        if let commentId { data["commentId"] = commentId }
        reports.addDocument(data: data) { error in
            if let error = error as NSError? {
                print("Sending the report failed: \(error.localizedDescription)")
            }
            done(error)
        }
    }
}
