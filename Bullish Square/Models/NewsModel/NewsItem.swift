//
//  NewsItem.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/6/21.
//

import UIKit

struct NewsItem {
    var headline: String
    var link: String
    var pubDate: String
    var ticker: String
    var author: String
    var image: UIImage
    
    static let previewNewsItem = [
        NewsItem(headline: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", author: "CNN", image: UIImage(named: "mw-logo")!),
        NewsItem(headline: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", author: "", image: UIImage(named: "mw-logo")!)
    ]
}

struct UserSavedNewsItem {
    var headline: String
    var link: String
    var pubDate: String
    var author: String
    var newsImageData: Data
}

struct SystemSavedNewsItem {
    var headline: String
    var pubDate: String
    var image: UIImage
}
