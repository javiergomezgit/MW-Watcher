//
//  StocksAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/10/22.
//

import Foundation

enum KeysStocksAPI {
    //Constants for search/add of single stock
    static let apiKeyStockSearchAdd = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let apiHost = "stock-data-yahoo-finance-alternative.p.rapidapi.com"
    static let baseUrlStockSearchAdd = "https://stock-data-yahoo-finance-alternative.p.rapidapi.com/v6/finance/quote?symbols="
    
    //Constants for getting logo for specific stock
    static let apiKeyLogoStockHost = "twelve-data1.p.rapidapi.com"
    static let apiKeyLogoStock = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let apiLogoBaseURL = "https://twelve-data1.p.rapidapi.com/logo?symbol="
    
    //Constants for single stock current price
    static let apiCurrentPriceHost = "apidojo-yahoo-finance-v1.p.rapidapi.com"
    static let apiCurrentPriceKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let apiCurrentPriceBaseURL = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols="
    
    //Constant when user type the ticker
    static let searchWhileTypeHost = "yh-finance.p.rapidapi.com"
    static let searchWhileTypeKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let searchWhileTypeBaseURL = "https://yh-finance.p.rapidapi.com/auto-complete?q="
    
    //Constant for a group of stocks with current price
    static let groupStocksPriceHost = "apidojo-yahoo-finance-v1.p.rapidapi.com"
    static let groupStocksPriceKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let groupStocksPriceBaseURL = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols="
    
    //Constant for general markets
    static let generalMarketKey = "oFf1Q9pDzb6LovcGuCciz1ngVdnCN04J1FGi2fLa"
    static let generalMarketHost = "yfapi.net"
    static let generalBaseURL = "https://yfapi.net/v6/finance/quote?region=US&lang=en&symbols=%5EDJI%2C%5EGSPC%2C%5EIXIC%2C%5EW5000%2C%5ERUA%2C%5ESP400%2C%5ERUT%2C%5EVIX"
}
