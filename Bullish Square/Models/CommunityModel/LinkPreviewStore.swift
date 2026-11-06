//
//  LinkPreviewStore.swift
//  Bullish Square
//

import UIKit
import LinkPresentation

///The title, site and picture of a web page, for the card under a post with a link. (BS-289)
///
///Read on the phone with LinkPresentation, as Messages does, so posts store nothing extra and
///the Firestore rules don't change. Each page is read once per launch however many rows show
///it; a page that can't be read is remembered too, so it isn't asked again while scrolling.
final class LinkPreviewStore {

    // MARK: - Properties

    struct Preview {
        let url: URL
        let title: String?
        ///"cnbc.com", without "www.".
        let site: String
        let image: UIImage?
    }

    static let shared = LinkPreviewStore()
    private init() {}

    private var previews: [URL: Preview] = [:]
    ///Callers waiting on a page already being read.
    private var waiting: [URL: [(Preview) -> Void]] = [:]

    // MARK: - Reading

    ///The first web address in a post's text, which the card shows.
    static func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let url = match.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                return url
            }
        }
        return nil
    }

    ///Already read, or nil.
    func cached(_ url: URL) -> Preview? {
        previews[url]
    }

    ///Calls back once, on the main queue. A page that can't be read still gives a preview
    ///with its site and no title or picture, so the card always has something to show.
    func load(_ url: URL, completion: @escaping (Preview) -> Void) {
        if let preview = previews[url] { return completion(preview) }
        if waiting[url] != nil {
            waiting[url]?.append(completion)
            return
        }
        waiting[url] = [completion]
        let provider = LPMetadataProvider()
        provider.timeout = 10
        provider.startFetchingMetadata(for: url) { [weak self] metadata, error in
            if let error = error as NSError? {
                print("Reading the link preview for \(url.host ?? "a page") failed: \(error.localizedDescription)")
            }
            let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let imageProvider = metadata?.imageProvider ?? metadata?.iconProvider,
                  imageProvider.canLoadObject(ofClass: UIImage.self) else {
                return DispatchQueue.main.async { self?.finish(url, title: title, image: nil) }
            }
            imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                //A page's picture can be several megapixels; the card shows it at 84pt.
                let thumbnail = (image as? UIImage).flatMap { Self.thumbnail($0) }
                DispatchQueue.main.async { self?.finish(url, title: title, image: thumbnail) }
            }
        }
    }

    private func finish(_ url: URL, title: String?, image: UIImage?) {
        let preview = Preview(url: url, title: title?.isEmpty == false ? title : nil,
                              site: Self.site(of: url), image: image)
        previews[url] = preview
        let callers = waiting.removeValue(forKey: url) ?? []
        callers.forEach { $0(preview) }
    }

    ///Filling a square of the card's height on a 3x screen.
    private static func thumbnail(_ image: UIImage) -> UIImage? {
        let side = LinkPreviewView.height * 3
        let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
        guard scale < 1 else { return image }
        return image.preparingThumbnail(of: CGSize(width: image.size.width * scale, height: image.size.height * scale))
    }

    static func site(of url: URL) -> String {
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
