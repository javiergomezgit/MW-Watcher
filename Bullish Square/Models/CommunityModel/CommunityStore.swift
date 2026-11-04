//
//  CommunityStore.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

///Everything Community reads and writes: posts, follows, likes, reshares, blocks and reports.
///(BS-265)
///
///Firestore layout - the rules (console) allow exactly these writes:
///- `posts/{postId}` and `posts/{postId}/likes/{uid}`, `posts/{postId}/reshares/{uid}`
///- `profiles/{uid}/following/{target}` with `profiles/{target}/followers/{uid}`, written together
///- `blocks/{blocker}_{blocked}`, readable by both
///- `reports/{id}`, create only
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

    var currentUid: String? { Auth.auth().currentUser?.uid }

    private func main<T>(_ completion: @escaping (T) -> Void) -> (T) -> Void {
        return { value in DispatchQueue.main.async { completion(value) } }
    }

    // MARK: - Feeds

    ///The latest posts from everyone.
    func discover(before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        var query: Query = posts
        if let before { query = query.whereField("createdAt", isLessThan: Timestamp(date: before)) }
        query = query.order(by: "createdAt", descending: true).limit(to: Self.pageSize)
        let done = main(completion)
        query.getDocuments { snapshot, error in
            if let error = error as NSError? {
                print("Loading the Discover feed failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
            done(.success(Self.page(from: snapshot?.documents ?? [])))
        }
    }

    ///Posts by the people you follow, and your own.
    func following(before: Date?, completion: @escaping (Result<Page, Error>) -> Void) {
        guard let uid = currentUid else { return main(completion)(.failure(CommunityError.notSignedIn)) }
        followingUIDs(of: uid) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let uids):
                self.posts(by: [uid] + uids, before: before, completion: completion)
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
            done(nil)
        }
    }

    // MARK: - Likes

    func like(_ post: Post, completion: @escaping (Error?) -> Void) {
        setMark("likes", on: post.id, counter: "likeCount", marked: true, completion: completion)
    }

    func unlike(_ post: Post, completion: @escaping (Error?) -> Void) {
        setMark("likes", on: post.id, counter: "likeCount", marked: false, completion: completion)
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
        batch.commit { error in
            if let error = error as NSError? {
                print("Resharing failed: \(error.localizedDescription)")
                return done(.failure(error))
            }
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
        batch.commit { [weak self] error in
            guard let error = error as NSError? else { return done(nil) }
            //The original may be gone; the reshare is still yours to delete.
            print("Undoing the reshare with its original failed, deleting it alone: \(error.localizedDescription)")
            self?.posts.document(postId).delete { error in done(error) }
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
        batch.commit { error in
            if let error = error as NSError? {
                print("Updating the follow failed: \(error.localizedDescription)")
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

    ///A post (with its author) or a profile. Javier reviews `reports` in the Firebase console.
    func report(postId: String?, userUid: String, reason: ReportReason, completion: @escaping (Error?) -> Void) {
        let done = main(completion)
        guard let uid = currentUid else { return done(CommunityError.notSignedIn) }
        var data: [String: Any] = [
            "reporterUid": uid,
            "userUid": userUid,
            "reason": reason.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let postId { data["postId"] = postId }
        reports.addDocument(data: data) { error in
            if let error = error as NSError? {
                print("Sending the report failed: \(error.localizedDescription)")
            }
            done(error)
        }
    }
}
