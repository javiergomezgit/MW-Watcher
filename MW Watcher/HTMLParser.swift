//
//  HTMLParser.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/17/21.
//

import SwiftSoup

class HTMLParser {
    
    private var rssItems: [RSSItem] = []

    func loadHTML(urlString: String, amountOfFeeds: Int) -> [RSSItem] {
        
        guard let url = (URL(string: urlString)) else { return rssItems }
        
        do {
            let contents = try String(contentsOf: url)
            let document: Document = try SwiftSoup.parse(contents)
            
            parseHTML(document: document, amountOfFeeds: amountOfFeeds - 1)
                        
        } catch {
            print (error)
        }
        
        return rssItems
    }
    
    
    func parseHTML(document: Document, amountOfFeeds: Int) {
        var countingFeeds = 0
        do {
            let articles: Elements = try document.getElementsByClass("element--article")
        
            for article in articles {
                let deatilsClass: Elements = try article.getElementsByClass("article__details")
                let detailsSpan: Elements = try deatilsClass.select("span")
                
                let bgQuoteElement: Elements = try article.select("bg-quote")
                let aBgQuoteElement: Elements = try bgQuoteElement.select("a")
                
                if let timeExists = try detailsSpan.first()?.text(), let _ = try aBgQuoteElement.first()?.attr("href") {
                    if countingFeeds <= amountOfFeeds {
                        let linkArticle: Elements = try article.select("a")
                        let link: String = try linkArticle.attr("href")
                        //print (link)
                        
                        let headline: Elements = try article.select("h3")
                        let headlineString = try headline.first()!.text()
                        
                        let imageArticle: Elements = try linkArticle.first()!.select("img")
                        let imageSources = try imageArticle.first()?.attr("data-srcset")
                        
                        var imageLink = ""
                        if let imageSource = imageSources?.split(separator: " ") {
                            imageLink = String(imageSource[0])
                        }
                        
                        let symbolElement: Elements = try aBgQuoteElement.select("span")
                        let symbolPercentageElement: Elements = try aBgQuoteElement.select("bg-quote")
                                                
                        let symbolPercentage = try symbolPercentageElement.first()!.text()
                        var symbol = try symbolElement.first()!.text()
                        let symbolLink = "https://finance.yahoo.com/quote/\(symbol)"
                        symbol = symbol + " " + symbolPercentage
                        
                        let newTime = newLocalTime(timeString: timeExists)

                        let rssitem = RSSItem.init(title: headlineString, link: link, pubDate: newTime, ticker: symbol, linkTicker: symbolLink, enclosure: imageLink)
                        rssItems.append(rssitem)
                        
                        countingFeeds += 1
                    }
                }
            }
            print (rssItems)
        } catch {
            print (error)
        }
        
    }
    
    func newLocalTime(timeString: String) -> String {
        
        var timeWithoutSpecialCharacters = timeString.replacingOccurrences(of: ".", with: "", options: NSString.CompareOptions.literal, range: nil)
        timeWithoutSpecialCharacters = timeWithoutSpecialCharacters.replacingOccurrences(of: "at ", with: "", options: NSString.CompareOptions.literal, range: nil)
        timeWithoutSpecialCharacters = timeWithoutSpecialCharacters.replacingOccurrences(of: " ET", with: "", options: NSString.CompareOptions.literal, range: nil)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        dateFormatter.dateFormat = "MMM dd, yyyy h:mm a"
        dateFormatter.timeZone = TimeZone(abbreviation: "EDT")
        
        let date = dateFormatter.date(from:timeWithoutSpecialCharacters)
        
        dateFormatter.timeZone = TimeZone.current
        let local = dateFormatter.string(from: date!)
        return String(local)
    }
    
}

