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
 "asset_id": "USD",
 "name": "US Dollar",
 "type_is_crypto": 0,
 "data_start": "2010-07-17",
 "data_end": "2021-06-12",
 "data_quote_start": "2014-02-24T17:43:05.0000000Z",
 "data_quote_end": "2021-06-12T15:47:23.6790000Z",
 "data_orderbook_start": "2014-02-24T17:43:05.0000000Z",
 "data_orderbook_end": "2020-08-05T14:38:00.7082850Z",
 "data_trade_start": "2010-07-17T23:09:17.0000000Z",
 "data_trade_end": "2021-06-12T15:47:23.1280000Z",
 "data_symbols_count": 62293,
 "volume_1hrs_usd": 4676848154094.24,
 "volume_1day_usd": 137590032091975.87,
 "volume_1mth_usd": 6466515236780999.71,
 "id_icon": "0a4185f2-1a03-4a7c-b866-ba7076d8c73b"
 */

struct Crypto: Codable {
    let asset_id: String
    let name: String?
    let price_usd: Float?
    let id_icon: String?
    
}

struct Icon: Codable {
    let asset_id: String
    let url: String
}
