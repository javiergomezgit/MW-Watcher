//
//  Provider.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//

import WidgetKit
import SwiftUI

//var rssItemsGlobal: [RSSItem] = []
var rssItemsImages: [RSSItemWithImages] = []

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // preview when installing/adding widget
        //let entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
        
        var entry : SimpleEntry
        
        if context.isPreview {
                entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
            } else {
                entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
            }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
     
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images
        //let mwURLString = "http://feeds.marketwatch.com/marketwatch/realtimeheadlines/"
        let feedParser = FeedParser()

        feedParser.parseFeed(url: mwURLString) { (rssItems) in

            var entries: [SimpleEntry] = []
            var entry: SimpleEntry
            var policy: TimelineReloadPolicy

            entry = SimpleEntry(date: Date(), mwfeed: rssItems)
            policy = .after(Calendar.current.date(byAdding: .minute, value: 1, to: Date())!)
            entries.append(entry)
    
            let timeline = Timeline(entries: entries, policy: policy)
            completion(timeline)
        }
    }
}
