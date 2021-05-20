//
//  SimpleEntry.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//


import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let mwfeed: [RSSItem]

    static let previewRSSItem = [
        RSSItem.init(title: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square Stock Is Down. Earnings Were Strong, but Expenses Will Rise.", link: "No link", pubDate: "Thu, 06 May 2021 15:32:27 -0700", ticker: "SQ-3.41%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square crushes earnings expectations amid continued growth of Cash App", link: "No link", pubDate: "Thu, 06 May 2021 14:52:56 -0700", ticker: "BKNG-2.51%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Making‘massive’ push in movies, adding 1,000 in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", linkTicker: "link", enclosure: ""),
        RSSItem.init(title: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", linkTicker: "No link", enclosure: "")
    ]
    
    static var testRSSItm = [RSSItem]()
}
