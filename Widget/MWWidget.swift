//
//  Widget.swift
//  Widget
//
//  Created by Javier Gomez on 5/4/21.
//

import WidgetKit
import SwiftUI

@main
struct MWWidget: Widget {
    let kind: String = "Market Watch Widget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()){ entry in
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
