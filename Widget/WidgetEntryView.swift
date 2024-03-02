//
//  WidgetEntryView.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//

import WidgetKit
import SwiftUI

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
            }
        }
    }

        
    var news: some View {
        Group {
            if family == .systemLarge {
                ForEach(0..<entry.mwfeed.count, id: \.self) { index in
                    if index < 6 {
                        HStack {
                            Image(uiImage: entry.mwfeed[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40, alignment: .center)
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack {
                                Text(entry.mwfeed[index].headline)
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
                                //.padding(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 4))
                            }
                        }
                    }
                }
            } else {
                ForEach(0..<entry.mwfeed.count, id: \.self) { index in
                    if index < 2 {
                        HStack {
                            Image(uiImage: entry.mwfeed[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40, alignment: .center)
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack {
                                Text(entry.mwfeed[index].headline)
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


            
            
//            if entry.mwfeed.count > 1 {
//                if family == .systemLarge {
//                    ForEach(0..<entry.mwfeed.count) { index in
//                        HStack {
//                            if entry.mwfeed[index].image == nil {
//                                Image("mw-logo")
//                                      .resizable()
//                                      .aspectRatio(contentMode: .fill)
//                                      .frame(width: 40, height: 40)
//                                      .foregroundColor(.white)
//                                      .clipShape(RoundedRectangle(cornerRadius: 7))
//                            } else {
//                                Image(systemName: "folder.circle")
//                                    //.data(url: URL(string: entry.mwfeed[index].image)!)
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 42, height: 42)
//                                    .foregroundColor(.white)
//                                    .clipShape(RoundedRectangle(cornerRadius: 8))
//                            }
//                            VStack {
//                                Text(entry.mwfeed[index].title)
//                                    .fixedSize(horizontal: false, vertical: true)
//                                    .lineLimit(2)
//                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
//                                    .foregroundColor(Color(UIColor.systemBackground))
//                                    .colorInvert()
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                                Text(entry.mwfeed[index].pubDate)
//                                    .font(Font.system(size: 9, weight: .light,  design: .default))
//                                    //.foregroundColor(/*@START_MENU_TOKEN@*/.gray/*@END_MENU_TOKEN@*/)
//                                    .foregroundColor(Color(UIColor.systemBackground))
//                                    .colorInvert()
//                                    .frame(maxWidth: .infinity, alignment: .trailing)
//                            }
//                        }
//                    }
//                } else {
//                    ForEach(0..<entry.mwfeed.count - 4) { index in
//                        HStack {
//                            if entry.mwfeed[index].image == "" {
//                                Image("mw-logo")
//                                      .resizable()
//                                      .aspectRatio(contentMode: .fill)
//                                      .frame(width: 40, height: 40)
//                                      .foregroundColor(.white)
//                                      .clipShape(RoundedRectangle(cornerRadius: 7))
//                            } else {
//                                Image(systemName: "folder.circle")
//                                    //.data(url: URL(string: entry.mwfeed[index].enclosure)!)
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 40, height: 40)
//                                    .foregroundColor(.white)
//                                    .clipShape(RoundedRectangle(cornerRadius: 7))
//                            }
//                            VStack {
//                                Text(entry.mwfeed[index].title)
//                                    .fixedSize(horizontal: false, vertical: true)
//                                    .lineLimit(2)
//                                    .font(Font.system(size: 12, weight: .semibold,  design: .default))
//                                    .foregroundColor(Color(UIColor.systemBackground))
//                                    .colorInvert()
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                                Text(entry.mwfeed[index].pubDate)
//                                    .font(Font.system(size: 9, weight: .light,  design: .default))
//                                    .foregroundColor(Color(UIColor.systemBackground))
//                                    .colorInvert()
//                                    .frame(maxWidth: .infinity, alignment: .trailing)
//                            }
//                        }
//                    }
//                }
//            }
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
