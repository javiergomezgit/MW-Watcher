//
//  NewsItem.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/6/21.
//

import UIKit

struct NewsItem {
    var headline: String
    var link: String
    var pubDate: String
    var ticker: String
    var author: String
    var image: UIImage
    
    static let previewNewsItem = [
        NewsItem(headline: "Paramount+ making‘massive’ in June and averaging a new original movie every week in 2022", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "ROKU-6.57%", author: "CNN", image: UIImage(named: "mw-logo")!),
        NewsItem(headline: "Roku stock gains after earnings, outlook top expectations", link: "No link", pubDate: "Thu, 06 May 2021 15:43:01 -0700", ticker: "VIAC-2.43", author: "", image: UIImage(named: "mw-logo")!)
    ]
}

struct UserSavedNewsItem {
    var headline: String
    var link: String
    var pubDate: String
}

struct SystemSavedNewsItem {
    var headline: String
    var pubDate: String
    var image: UIImage
}

//MARK: Crypto Model

/*
 {
     "data": {
         "BTC": {
             "id": 1,
             "name": "Bitcoin",
             "symbol": "BTC",
             "slug": "bitcoin",
             "num_market_pairs": 9756,
             "date_added": "2013-04-28T00:00:00.000Z",
             "tags": [
                 "mineable",
                 "pow",
                 "sha-256",
                 "store-of-value",
                 "state-channels",
                 "coinbase-ventures-portfolio",
                 "three-arrows-capital-portfolio",
                 "polychain-capital-portfolio",
                 "binance-labs-portfolio",
                 "arrington-xrp-capital",
                 "blockchain-capital-portfolio",
                 "boostvc-portfolio",
                 "cms-holdings-portfolio",
                 "dcg-portfolio",
                 "dragonfly-capital-portfolio",
                 "electric-capital-portfolio",
                 "fabric-ventures-portfolio",
                 "framework-ventures",
                 "galaxy-digital-portfolio",
                 "huobi-capital",
                 "alameda-research-portfolio",
                 "a16z-portfolio",
                 "1confirmation-portfolio",
                 "winklevoss-capital",
                 "usv-portfolio",
                 "placeholder-ventures-portfolio",
                 "pantera-capital-portfolio",
                 "multicoin-capital-portfolio",
                 "paradigm-xzy-screener"
             ],
             "max_supply": 21000000,
             "circulating_supply": 18734450,
             "total_supply": 18734450,
             "is_active": 1,
             "platform": null,
             "cmc_rank": 1,
             "is_fiat": 0,
             "last_updated": "2021-06-14T04:52:02.000Z",
             "quote": {
                 "USD": {
                     "price": 39248.232180201485,
                     "volume_24h": 43149561503.525696,
                     "percent_change_1h": 0.98757247,
                     "percent_change_24h": 11.64561834,
                     "percent_change_7d": 8.10445013,
                     "percent_change_30d": -20.64356666,
                     "percent_change_60d": -37.83630061,
                     "percent_change_90d": -28.20907292,
                     "market_cap": 735294043368.3757,
                     "last_updated": "2021-06-14T04:52:02.000Z"
                 }
             }
         },
 */

struct CryptoAPIResponse: Codable {
    let data: [String: CryptoData]
}

struct CryptoData: Codable {
    let id: Int
    let name: String
    let symbol: String
    let quote: [String: Quote]
}

struct Quote: Codable {
    let price: Float
    let percent_change_24h: Float
    let percent_change_30d: Float
    let volume_24h: Float
}



struct CryptoIndividualAPIResponse: Codable {
    let data: [String: CryptoIndividualData]
}
struct CryptoIndividualData: Codable {
    let status: String
    let quotes: [String: QuoteInvidual]
}
struct QuoteInvidual: Codable {
    let startingAt: String
    let open: Float
    let high: Float
    let low: Float
    let close: Float
    let avg: Float?
}





