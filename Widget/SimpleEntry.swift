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
    let mwfeed: [SystemSavedNewsItem]


    static let previewNewsItem = [
        SystemSavedNewsItem.init(
            headline: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022",
            pubDate: "Thu, 06 May 2021 15:43:01 -0700",
            image: UIImage(named: "mw-logo")!),
        SystemSavedNewsItem.init(
            headline: "Roku stock gains after earnings, outlook top expectations",
            pubDate: "Thu, 06 May 2021 15:32:27 -0700",
            image: UIImage(named: "mw-logo")!),
        SystemSavedNewsItem.init(
            headline: "Square Stock Is Down. Earnings Were Strong, but Expenses Will Rise",
            pubDate: "Thu, 06 May 2021 15:32:27 -0700",
            image: UIImage(named: "mw-logo")!),
        SystemSavedNewsItem.init(
            headline: "Square crushes earnings expectations amid continued growth of Cash App",
            pubDate: "Thu, 06 May 2021 15:32:27 -0700",
            image: UIImage(named: "mw-logo")!),
        SystemSavedNewsItem.init(
            headline: "Making‘massive’ push in movies, adding 1,000 in June and averaging a new original movie every week in 2022",
            pubDate: "Thu, 06 May 2021 15:32:27 -0700",
            image: UIImage(named: "mw-logo")!),
        SystemSavedNewsItem.init(
            headline: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022",
            pubDate: "Thu, 06 May 2021 15:32:27 -0700",
            image: UIImage(named: "mw-logo")!)
    ]
}
