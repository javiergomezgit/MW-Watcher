//
//  Widget.swift
//  Widget
//
//  Created by Javier Gomez on 5/4/21.
//

import WidgetKit
import SwiftUI
import Intents

var rssItemsGlobal: [RSSItem] = []

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // preview when installing/adding widget
        let entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
        
//        if context.isPreview {
//                entry = MyTimelineEntry(date: date, title: "—", content: "-")
//            } else {
//                entry = MyTimelineEntry(date: date, title: snapshotTitle, content: snapshotContent)
//            }
        
        
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        //real action
        
//        var entries: [SimpleEntry] = []
//
//        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
//        let currentDate = Date()
//        for hourOffset in 0 ..< 5 {
//
//            fetch()
//
//            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset, to: currentDate)!
//            let entry = SimpleEntry(date: entryDate, mwfeed: rssItemsGlobal)
//            entries.append(entry)
//        }
//
//        let timeline = Timeline(entries: entries, policy: .atEnd)
//        completion(timeline)
        

        
        
        
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images
        let feedParser = FeedParser()
        let currentDate = Date()
        
        print ("enter timeline")
        
        
        feedParser.parseFeed(url: mwURLString) { (rssItems) in
            
            print ("enter completion")
            
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
    
    
    func fetch() {
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images
        let feedParser = FeedParser()
        
        print ("enter fetch")
        feedParser.parseFeed(url: mwURLString) { (rssItems) in
            rssItemsGlobal = rssItems
            print ("load rss")
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                print ("reload")
            }
        }
        
        
        
        
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let mwfeed: [RSSItem]
    
    static let previewRSSItem = [RSSItem.init(title: "test title", link: "test link", pubDate: "test date", ticker: "test ticker", linkTicker: "test link ti", enclosure: "test enclosure")]
    
    static let testRSSItem = [RSSItem.init(title: "morooo test title", link: "test link", pubDate: "test date", ticker: "test ticker", linkTicker: "test link ti", enclosure: "test enclosure")]
}

struct WidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack{
            VStack() {
                if family == .systemLarge {
                    header
                    news
                    Text("Source: www.marketwatch.com")
                        .font(Font.system(size: 10, weight: .light,  design: .default))
                        .foregroundColor(Color(UIColor.systemBlue))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.bottom, -7)
                } else {
                    headermedium
                    news
                    Text("Source: www.marketwatch.com")
                        .font(Font.system(size: 10, weight: .light,  design: .default))
                        .foregroundColor(Color(UIColor.systemBlue))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.bottom, 15)
                }
            }
            .padding(.all, 10)
        }
        
    }
    
    var header: some View {
        Group {
            ZStack (alignment: .center) {
                Text("Market News")
                    .font(.system(size: 16))
                    .foregroundColor(Color(UIColor.systemBlue))
                    .fontWeight(.semibold)
                    .opacity(0.7)
                Spacer()
            }
        }
    }
    
    var headermedium: some View {
        Group {
            VStack (alignment: .center) {
                Text("Market News")
                    .font(.system(size: 12))
                    .foregroundColor(Color(UIColor.systemBlue))
                    .fontWeight(.semibold)
                    .padding(.bottom, 1)
                    .padding(.top, 15)

            }
        }
    }
        
    var news: some View {
        Group {
            if entry.mwfeed.count > 1 {
                if family == .systemLarge {
                    ForEach(0..<entry.mwfeed.count - 4) { index in
                        HStack {
                            Image("mw-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                //.padding(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 4))
                                .frame(width: 45, height: 45)
                                .foregroundColor(.white)
                                //.clipShape(Circle())
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack {
                                Text(entry.mwfeed[index].title)
                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.mwfeed[index].pubDate)
                                .font(Font.system(size: 9, weight: .light,  design: .default))
                                .foregroundColor(Color(UIColor.systemBackground))
                                .opacity(0.7)
                                .colorInvert()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    ForEach(0..<entry.mwfeed.count - 7) { index in
                        HStack {
                            Image("mw-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                //.padding(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 4))
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
//                                .clipShape(Circle())
                            VStack {
                                Text(entry.mwfeed[index].title)
                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.mwfeed[index].pubDate)
                                .font(Font.system(size: 9, weight: .light,  design: .default))
                                .foregroundColor(Color(UIColor.systemBackground))
                                .opacity(0.7)
                                .colorInvert()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

        }
    }
}

@main
struct MWWidget: Widget {
    let kind: String = "Market Watch Widget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Market Watch Widget")
        .description("Watcher widget for www.marketwatch.com")
        .supportedFamilies([.systemLarge, .systemMedium])
    }
}

//struct Widget_Previews: PreviewProvider {
//    static var previews: some View {
//        WidgetEntryView(entry: SimpleEntry(date: Date(), title: "preview"))
//            .previewContext(WidgetPreviewContext(family: .systemLarge))
//    }
//}
