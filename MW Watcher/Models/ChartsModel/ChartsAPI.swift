//
//  ChartsAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/6/22.
//

import Foundation

enum KeysChartsAPI {
    //API call fo stocks char
    static let getStockApiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let getStockApiHost = "yahoo-finance15.p.rapidapi.com"
    static let getStockBaseUrl = "https://yahoo-finance15.p.rapidapi.com/api/yahoo/hi/history/"
    static let getStockEndpoint = "?diffandsplits=false"
    
    //API keys for general market
    static let getGeneralMarketApiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let getGeneralMarketApiHost = "mboum-finance.p.rapidapi.com"
    static let getGeneralMarketBaseUrl = "https://mboum-finance.p.rapidapi.com/hi/history?symbol="
    
    //API keys for majors markets
    static let getMajorsMarketsApiKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let getMajorsMarketsApiHost = "mboum-finance.p.rapidapi.com"
    static let getMajorsMarketsBaseUrl = "https://mboum-finance.p.rapidapi.com/hi/history?symbol="
    
    //API general markets and watchlist
    static let getGeneralWatchkey = "oFf1Q9pDzb6LovcGuCciz1ngVdnCN04J1FGi2fLa"
    static let getGeneralWatchHost = "yfapi.net"
    static let getGeneralWatchBaseUrl = "https://yfapi.net/v8/finance/spark?"
    
}

