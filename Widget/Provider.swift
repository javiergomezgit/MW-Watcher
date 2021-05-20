//
//  Provider.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//

import WidgetKit
import SwiftUI

var rssItems: [RSSItem] = []
var memoryFeeds = SaveFeedsWidget()

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // preview when installing/adding widget
        var entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
        if !context.isPreview {
            let memoryFeeds = SaveFeedsWidget()
            let rssItems = memoryFeeds.loadSavedFeeds()
            
            entry = SimpleEntry(date: Date(), mwfeed: rssItems)
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        
            let mwURLString = "https://www.marketwatch.com/latest-news"
            let parsingHTML = HTMLParser()
            rssItems = parsingHTML.loadHTML(urlString: mwURLString, amountOfFeeds: 6)
             
            if rssItems.isEmpty {
                rssItems = memoryFeeds.loadSavedFeeds()
            } else {
                memoryFeeds.deleteSavedFeeds()
                for rssItem in rssItems {
                    memoryFeeds.saveOnlineFeeds(title: rssItem.title, link: rssItem.link, pubDate: rssItem.pubDate, ticker: rssItem.ticker, linkTicker: rssItem.linkTicker, enclosure: rssItem.enclosure)
                }
            }
    
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
