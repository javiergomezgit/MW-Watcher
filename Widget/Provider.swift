//
//  Provider.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//

import WidgetKit
import SwiftUI

var newsItems: [SystemSavedNewsItem] = []
var memoryFeeds = SaveFeedsWidget()

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewNewsItem)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // preview when installing/adding widget
        var entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewNewsItem)
        if !context.isPreview {
            let memoryFeeds = SaveFeedsWidget()
            let newsItems = memoryFeeds.loadSavedFeeds()
            
            entry = SimpleEntry(date: Date(), mwfeed: newsItems)
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {

        print ("gettimeline")

        fetchData { (newsItemsLocal) in
            print ("enter completion")
            let nextUpdate = Date().addingTimeInterval(60)
            let entry = SimpleEntry(date: nextUpdate, mwfeed: newsItemsLocal)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            
            completion(timeline)
            
        }

        

    }
    
    func fetchData(completion: @escaping ([SystemSavedNewsItem]) -> Void) {
        
        print ("enter parsing")
        let mwURLString = "https://www.marketwatch.com/latest-news"
        let parsingHTML = HTMLParser()
        
        newsItems = parsingHTML.loadHTML(urlString: mwURLString, amountOfFeeds: 6)
        
        completion(newsItems)
    }
    
    
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage()
        let url = URL(string: URLImage)
        do {
            let data = try Data(contentsOf: url!)
            let imageToCache = UIImage(data: data)!
            imageCache.setObject(imageToCache, forKey: URLImage as NSString)
            image = imageToCache
        } catch {
            image = UIImage(named: "mw-logo")!
        }
        return image
    }
    
    func newLocalTime(timeString: String) -> String {

        var timeWithoutSpecialCharacters = timeString.replacingOccurrences(of: "T", with: " ", options: NSString.CompareOptions.literal, range: nil)
        timeWithoutSpecialCharacters = timeWithoutSpecialCharacters.replacingOccurrences(of: ".0000000Z ", with: "", options: NSString.CompareOptions.literal, range: nil)
        let formatted = timeWithoutSpecialCharacters.components(separatedBy: ".")

        return formatted[0]
    }
}
