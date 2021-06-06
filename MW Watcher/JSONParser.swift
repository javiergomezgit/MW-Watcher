//
//  JSONParser.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/4/21.
//

import Foundation

class NewsParser {
    
    private var rssItems: [RSSItem] = []
    
    //ticker in news will change to author
    //link to ticker will be empty
    
    func loadNews() -> [RSSItem]{
        
        let headers = [
            "x-bingapis-sdk": "true",
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "bing-news-search1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url: NSURL(string: "https://bing-news-search1.p.rapidapi.com/news?safeSearch=Off&category=Business")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error)
            } else {
                let httpResponse = response as? HTTPURLResponse
                print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                //print (json!)
                
                let jsonNews = json!["value"] as! [Any]
                
                for jsonNew in jsonNews {
                    
                    //print (jsonNew)
                    let dictionaryNew = jsonNew as! [String: Any]
                    
                    let pubDate = dictionaryNew["datePublished"] as! String
                    
                    let headline = dictionaryNew["name"] as! String
                    
                    let link = dictionaryNew["url"] as! String
                    
                    print (dictionaryNew)
                    let imageDictionary = dictionaryNew["image"] as? [String : Any]
                    print (imageDictionary)
                    
                    var imageLink = ""
                    if imageDictionary != nil {
                        let imageJSON = imageDictionary?["thumbnail"] as? [String: Any]
                        print (imageJSON)
                        imageLink = imageJSON?["contentUrl"] as! String
                    }
                                
                    let authorDictionary = dictionaryNew["provider"] as! [Any]
                    let authorArray = authorDictionary.first as! [String: Any]
                    let author = authorArray["name"] as! String
                    
                    let rssitem = RSSItem.init(title: headline, link: link, pubDate: pubDate, ticker: author, linkTicker: "", enclosure: imageLink)
                    self.rssItems.append(rssitem)
                }
                
                print (self.rssItems)
            }
        })
        dataTask.resume()
        
        return rssItems
    }
    
}


/*
 func loadCurrentPrices() {
 let headers = [
     "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
     "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
 ]

 let request = NSMutableURLRequest(url: NSURL(string: "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=%5EDJI%2C%5EGSPC%2CNDAQ%2C%5EW5000%2C%5ERUA%2C%5ESP400%2C%5ERUT%2CBTC-USD%2C%5EVIX&interval=1d&range=1d")! as URL,
                                         cachePolicy: .useProtocolCachePolicy,
                                     timeoutInterval: 10.0)
 request.httpMethod = "GET"
 request.allHTTPHeaderFields = headers

 let session = URLSession.shared
 let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
     if (error != nil) {
         print(error!)
     } else {
         let httpResponse = response as? HTTPURLResponse
         print (httpResponse!)
         
         let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
         print (json!)
         
         for tickerJSON in json! {
             print (tickerJSON.value) //json values prices etc
             print (tickerJSON.key) //ticker
             
             let tickerDictionary = tickerJSON.value as? [String: Any]
             
             let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
             
             let closePriceArray = tickerDictionary!["close"] as? [Any]
             
             let currentPrice = closePriceArray!.first as! Double
             
             let marketsNameValues = self.marketsPrices[tickerJSON.key]
             let nameOfMarket = marketsNameValues![0]
             
             self.marketsPrices[tickerJSON.key] = [nameOfMarket, currentPrice, previousClose]
         }
         print (self.marketsPrices)
         
         DispatchQueue.main.async {
             self.refreshControl.endRefreshing()
             self.collectionView.reloadData()
         }
     }
 })

 dataTask.resume()
}*/
