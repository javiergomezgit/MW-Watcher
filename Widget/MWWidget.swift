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
        //let entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)

        
        var entry : SimpleEntry

        
        if context.isPreview {
                entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
            } else {
                entry = SimpleEntry(date: Date(), mwfeed: SimpleEntry.previewRSSItem)
            }
        
        
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
     
        let mwURLString = "https://politepol.com/fd/MiMDjbYvoJdo" //Feed with images
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


struct SimpleEntry: TimelineEntry {
    let date: Date
    let mwfeed: [RSSItem]

    static let previewRSSItem = [
        RSSItem.init(title: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square Stock Is Down. Earnings Were Strong, but Expenses Will Rise.", link: "No link", pubDate: "Thu, 06 May 2021 15:32:27 -0700", ticker: "SQ-3.41%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square crushes earnings expectations amid continued growth of Cash App", link: "No link", pubDate: "Thu, 06 May 2021 14:52:56 -0700", ticker: "BKNG-2.51%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Making‘massive’ push in movies, adding 1,000 in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", linkTicker: "link", enclosure: ""),
        RSSItem.init(title: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square Stock Is Down. Earnings Were Strong, but Expenses Will Rise.", link: "No link", pubDate: "Thu, 06 May 2021 15:32:27 -0700", ticker: "SQ-3.41%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square crushes earnings expectations amid continued growth of Cash App", link: "No link", pubDate: "Thu, 06 May 2021 14:52:56 -0700", ticker: "BKNG-2.51%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square Stock Is Down. Earnings Were Strong, but Expenses Will Rise.", link: "No link", pubDate: "Thu, 06 May 2021 15:32:27 -0700", ticker: "SQ-3.41%", linkTicker: "No link", enclosure: ""),
        RSSItem.init(title: "Square crushes earnings expectations amid continued growth of Cash App", link: "No link", pubDate: "Thu, 06 May 2021 14:52:56 -0700", ticker: "BKNG-2.51%", linkTicker: "No link", enclosure: "")
    ]
}


struct WidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        ZStack{
            if colorScheme == .light {
                Color.white
                    .ignoresSafeArea(.all)
            } else if colorScheme == .dark {
                Color("customBackgroundColor")
                    .ignoresSafeArea(.all)
            }
            VStack(alignment: .leading) {
                header
                news
            }
            .padding(EdgeInsets(top: 7, leading: 15, bottom: 10, trailing: 15))
        }
        
    }
    
    var header: some View {
        Group {
            ZStack (alignment: .leading) {
                if family == .systemLarge {
                    Text("Market Watcher")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("titlesColor"))
                } else {
                    Text("Market Watcher")
                        .font(.footnote)
                        .foregroundColor(Color("titlesColor"))
                        .fontWeight(.bold)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                }
                    //.opacity(0.7)
                    //Spacer()
                    //.padding(.bottom, 1)
                    //.padding(.top, 15)
            }
        }
    }

        
    var news: some View {
        Group {
            if entry.mwfeed.count > 1 {
                if family == .systemLarge {
                    ForEach(0..<entry.mwfeed.count - 4) { index in
                        HStack {
                            if entry.mwfeed[index].enclosure == "" {
                                Image("mw-logo")
                                      .resizable()
                                      .aspectRatio(contentMode: .fill)
                                      .frame(width: 40, height: 40)
                                      .foregroundColor(.white)
                                      .clipShape(RoundedRectangle(cornerRadius: 7))
                            } else {
                                Image(systemName: "folder.circle")
                                    .data(url: URL(string: entry.mwfeed[index].enclosure)!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    //.padding(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 4))
                                    .frame(width: 42, height: 42)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            VStack {
                                Text(entry.mwfeed[index].title)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(2)
                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.mwfeed[index].pubDate)
                                    .font(Font.system(size: 9, weight: .light,  design: .default))
                                    //.foregroundColor(/*@START_MENU_TOKEN@*/.gray/*@END_MENU_TOKEN@*/)
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                } else {
                    ForEach(0..<entry.mwfeed.count - 8) { index in
                        HStack {
                            if entry.mwfeed[index].enclosure == "" {
                                Image("mw-logo")
                                      .resizable()
                                      .aspectRatio(contentMode: .fill)
                                      .frame(width: 40, height: 40)
                                      .foregroundColor(.white)
                                      .clipShape(RoundedRectangle(cornerRadius: 7))
                            } else {
                                Image(systemName: "folder.circle")
                                    .data(url: URL(string: entry.mwfeed[index].enclosure)!)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            VStack {
                                Text(entry.mwfeed[index].title)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(2)
                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.mwfeed[index].pubDate)
                                    .font(Font.system(size: 9, weight: .light,  design: .default))
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .colorInvert()
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
            }

        }
    }
}

extension Image {
    func data(url:URL) -> Self {
        if let data = try? Data(contentsOf: url) {
            return Image(uiImage: UIImage(data: data)!)
                .resizable()
        } else {
            return Image(uiImage: UIImage(named: "mw-logo")!)
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
