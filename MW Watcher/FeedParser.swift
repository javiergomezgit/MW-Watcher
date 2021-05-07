//
//  FeedParser.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import Foundation

class FeedParser: NSObject, XMLParserDelegate {
  
    private var rssItems: [RSSItem] = []
    private var parserCompletionHandler: (([RSSItem]) -> Void)?
    private var currentElement = ""
    private var countFeeds = 0
    
    private var currentTitle: String = "" {
        didSet {
            currentTitle = currentTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }
    private var currentLink: String = "" {
        didSet {
            currentLink = currentLink.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }
    private var currentPubdate: String = "" {
        didSet {
            currentPubdate = currentPubdate.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }
    private var currentTicker: String = "" {
        didSet {
            currentTicker = currentTicker.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }
    
    private var currentEnclosure: String = "" {
        didSet {
            currentEnclosure = currentEnclosure.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
    }

    func parseFeed(url: String, completionHandler:@escaping ([RSSItem]) -> Void) {
        
        self.parserCompletionHandler = completionHandler
        
        let request = URLRequest(url: URL(string: url)!)
        let urlSession = URLSession.shared
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                if let error = error {
                    print (error.localizedDescription)
                }
                return
            }
            
            //parse xml data
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }
        task.resume()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        currentElement = elementName
        
        if currentElement == "enclosure" {
            currentEnclosure = attributeDict["url"]!
        } else {
            currentEnclosure = ""
        }
        
        if currentElement == "item" {
            currentTitle = ""
            currentLink = ""
            currentTicker = ""
            currentPubdate = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        //second,  when found characters
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubdate += string
        case "description":
            currentTicker += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
 
        if countFeeds <= 9 {
            if elementName == "item" {
                let tickerValues = cleanTickerHTML(description: currentTicker)
                let calculatedTime = newTime(timeString: currentPubdate)
                let cleanURLImage = cleanURLImage(imgURL: currentEnclosure)
                
                let rssItem = RSSItem(title: currentTitle, link: currentLink, pubDate: calculatedTime, ticker: tickerValues[0], linkTicker: tickerValues[1], enclosure: cleanURLImage)
                self.rssItems.append(rssItem)
                countFeeds += 1
            }
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        parserCompletionHandler?(rssItems)
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print (parseError.localizedDescription)
    }
    
    
    func cleanURLImage(imgURL: String) -> String {
        
        var urlString = [""]
        if imgURL != "" {
            urlString = imgURL.components(separatedBy: ",")
        }
        
        return urlString[0]
    }
    
    func cleanTickerHTML(description: String) -> [String] {
                
        var values = ["", ""]
        let data = Data(description.utf8)
        
        if description != "" {
            if let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {

                values[0] = attributedString.string
    
                // retrieve attributes
                let attributes = attributedString.attributes(at: 0, effectiveRange: nil)

                // iterate each attribute
                for attr in attributes {
                    if attr.key.rawValue == "NSLink" {
                        let temp = attr.value as! NSURL
                        values[1] = temp.absoluteString!
                    }
                }
            }
        }
        
        return values
    }
    
    func newTime(timeString: String) -> String {
                
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
      
        let date = dateFormatter.date(from:timeString)
        let newDate = dateFormatter.string(from: date!)
        
        let cleanString = newDate.components(separatedBy: " -")
                
        return cleanString[0]
    }
}

