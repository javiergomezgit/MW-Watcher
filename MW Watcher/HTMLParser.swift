//
//  HTMLParser.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/17/21.
//

import SwiftSoup

class HTMLParser {

    private var newsItems: [SystemSavedNewsItem] = []

    func loadHTML(urlString: String, amountOfFeeds: Int) -> [SystemSavedNewsItem] {

        guard let url = (URL(string: urlString)) else { return newsItems }

        do {
            let contents = try String(contentsOf: url)
            let document: Document = try SwiftSoup.parse(contents)
            parseHTML(document: document, amountOfFeeds: amountOfFeeds - 1)
        } catch {
            print (error)
        }
        return newsItems
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
                        //let link: String = try linkArticle.attr("href") for using it in future to link to web/app

                        let worddline: Elements = try article.select("h3")
                        let worddlineString = try worddline.first()!.text()

                        let imageArticle: Elements = try linkArticle.first()!.select("img")
                        let imageSources = try imageArticle.first()?.attr("data-srcset")

                        var image = UIImage()
                        if let imageSource = imageSources?.split(separator: " ") {
                            let imageLink = String(imageSource[0])
                            image = downloadImageFeed(URLImage: imageLink)
                        } else {
                            image = UIImage(named: "mw-logo")!
                        }
                        

                        let symbolElement: Elements = try aBgQuoteElement.select("span")
                        let symbolPercentageElement: Elements = try aBgQuoteElement.select("bg-quote")

                        let symbolPercentage = try symbolPercentageElement.first()!.text()
                        var symbol = try symbolElement.first()!.text()
                        symbol = symbol + " " + symbolPercentage

                        let newTime = newLocalTime(timeString: timeExists)
                        let filteredHeadline = cleanHeadline(title: worddlineString)

                        let newsItem = SystemSavedNewsItem.init(headline: filteredHeadline, pubDate: newTime, image: image)
                        newsItems.append(newsItem)

                        countingFeeds += 1
                    }
                }
            }
        } catch {
            print (error)
        }
    }


    func cleanHeadline(title: String) -> String {
        var cleanArray = ""
        let words = title.uppercased().wordList

        for word in words {
            if word != "OF" &&
                word != "A" &&
                word != "AN" &&
                word != "SO" &&
                word != "AND" &&
                word != "THE" &&
                word != "AND" &&
                word != "OR" &&
                word != "FOR" &&
                word != "TO" &&
                word != "FROM" &&
                word != "ON" &&
                word != "IT'S" &&
                word != "IT" &&
                word != "TOO" &&
                word != "HE" &&
                word != "IN" &&
                word != "OF" &&
                word != "IS"  {

                if !cleanArray.isEmpty {
                    cleanArray = cleanArray + " " + word
                } else {
                    cleanArray = word
                }
            }
        }

        return cleanArray
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

}

extension String {
    var wordList: [String] {
        return components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}

