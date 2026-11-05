//
//  PostToCommunity.swift
//  Bullish Square
//

import UIKit
import FirebaseAuth

///Turns a news article or a chart into a Community post. A news row's own button, or
///"Post to Community" in the share sheet, opens the composer with the headline, its link and
///the ticker already written (a chart brings its picture), and the cursor at the top for the
///person's own take. Reading news and posting about it were two separate places; this makes
///the news the start of a conversation. (BS-285)
enum PostToCommunity {

    ///The Community tab's icon, so the button reads as "to Community", not as a message.
    static let symbolName = "person.2"

    // MARK: - Share sheet

    ///The share sheet for an article, with "Post to Community" among its actions. `ticker`
    ///is the stock the article is listed under, when there is one.
    static func shareSheet(items: [Any], headline: String, link: String, ticker: String? = nil,
                           from presenter: UIViewController) -> UIActivityViewController {
        shareSheet(items: items, text: draft(headline: headline, link: link, ticker: ticker), from: presenter)
    }

    ///The share sheet for anything, posting `text` and `photos` when "Post to Community" is
    ///chosen.
    static func shareSheet(items: [Any], text: String, photos: [UIImage] = [],
                           from presenter: UIViewController) -> UIActivityViewController {
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: [Activity()])
        //The composer is presented once the sheet has gone; presenting over it fails.
        sheet.completionWithItemsHandler = { [weak presenter] type, completed, _, _ in
            guard completed, type == Activity.type, let presenter else { return }
            start(text: text, photos: photos, from: presenter)
        }
        return sheet
    }

    ///Two empty lines for the person's take, then the headline, the link and the $TICKER,
    ///cut to fit a post.
    static func draft(headline: String, link: String, ticker: String?) -> String {
        var lines = [headline.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let url = URL(string: link), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            lines.append(link)
        }
        //Only a symbol a post can link: "^GSPC" or "BTC-USD" would be plain text.
        if let ticker, Post.tickers(in: "$\(ticker)") == [ticker.uppercased()] {
            lines.append("$\(ticker.uppercased())")
        }
        return String(("\n\n" + lines.joined(separator: "\n")).prefix(Post.textMaximumLength))
    }

    ///A chart's line, "$AAPL Apple Inc.", under room for the person's take; the chart picture
    ///carries the price. The name is left out when it is only the symbol again. `ticker` is
    ///the stock's symbol; crypto and indexes have none, as "$BTC" would link the wrong chart.
    static func chartDraft(symbol: String, name: String, ticker: String?) -> String {
        let linked = ticker.flatMap { Post.tickers(in: "$\($0)") == [$0.uppercased()] ? "$\($0.uppercased())" : nil }
        let shown = linked ?? symbol
        let bare = shown.hasPrefix("$") ? String(shown.dropFirst()) : shown
        let named = name.isEmpty || name.uppercased() == bare.uppercased() ? nil : name
        return "\n\n" + [shown, named].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: - Composing

    ///Signed in, guidelines accepted, then the composer with `text` and `photos`.
    static func start(text: String, photos: [UIImage] = [], from presenter: UIViewController) {
        guard Auth.auth().currentUser != nil else {
            return Utilities.showAlert(on: presenter, title: "Sign In", message: "Sign in to post in Community.")
        }
        CommunityGuidelines.hasAccepted { [weak presenter] accepted in
            guard let presenter else { return }
            let compose = { [weak presenter] in
                guard let presenter else { return }
                let composer = ComposePostController()
                composer.initialText = text
                composer.initialPhotos = photos
                composer.onPosted = { [weak presenter] _ in
                    guard let presenter else { return }
                    Utilities.showAlert(on: presenter, title: "Posted",
                                        message: "Your post is in Community, in Discover and on your profile.")
                }
                presenter.present(UINavigationController(rootViewController: composer), animated: true)
            }
            if accepted { return compose() }
            let terms = CommunityTermsController()
            terms.onAccept = compose
            presenter.present(UINavigationController(rootViewController: terms), animated: true)
        }
    }

    // MARK: - News row button

    ///The row button's one action; adding another with this identifier replaces it.
    static let buttonActionID = UIAction.Identifier("com.bullishsquare.postToCommunity.row")

    ///A "Post to Community" button just before a news row's share button. The storyboard rows
    ///tie the view before share (the link button, the source label) to share; those ties move
    ///to the new button, so nothing runs under it.
    static func addButton(before shareButton: UIButton) -> UIButton {
        let button = UIButton(type: .system)
        //The Community tab's own icon, smaller than share's: two figures are wider than an arrow
        //out of a box, so at the same size it looked the bigger of the two.
        let symbol = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        button.setImage(UIImage(systemName: PostToCommunity.symbolName, withConfiguration: symbol), for: .normal)
        button.tintColor = shareButton.tintColor
        button.accessibilityLabel = "Post to Community"
        guard let bar = shareButton.superview else { return button }
        button.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(button)

        for constraint in bar.constraints {
            //"share.leading = x.trailing": x now ends at the button instead.
            if constraint.firstItem === shareButton, constraint.firstAttribute == .leading,
               let other = constraint.secondItem as? UIView {
                constraint.isActive = false
                other.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -constraint.constant).isActive = true
            }
            //A label sized to a share of the bar may now reach the button; it gives way instead.
            if let label = constraint.firstItem as? UILabel, constraint.firstAttribute == .width,
               constraint.secondItem === bar, constraint.priority == .required {
                constraint.isActive = false
                constraint.priority = .defaultHigh
                constraint.isActive = true
                label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -6).isActive = true
            }
        }
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -6),
            button.centerYAnchor.constraint(equalTo: shareButton.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])
        return button
    }

    // MARK: - Activity

    ///The share sheet's action. It does nothing itself; the sheet's completion opens the
    ///composer once the sheet is gone.
    private final class Activity: UIActivity {
        static let type = UIActivity.ActivityType("com.bullishsquare.postToCommunity")

        ///`.share` puts it in the row of apps (Messages, Mail), not the list below. The row of
        ///people and AirDrop above that is the system's; apps can't add to it.
        override class var activityCategory: UIActivity.Category { .share }
        override var activityType: UIActivity.ActivityType? { Self.type }
        override var activityTitle: String? { "Post to Community" }
        override var activityImage: UIImage? { UIImage(systemName: PostToCommunity.symbolName) }

        override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

        override func perform() {
            activityDidFinish(true)
        }
    }
}
