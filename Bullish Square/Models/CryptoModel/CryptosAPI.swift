//
//  CryptoAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import Foundation

enum KeysAndConstants {
    //Constants for all cryptos API
    static let apiKey = "5e49ce50-9d28-431f-97a3-5661a78e0a4f"
    static let apiHeader = "X-CMC_PRO_API_KEY"
    static let baseUrl = "https://pro-api.coinmarketcap.com/v1/"
    static let symbols = "btc,eth,ltc,doge,ada,dot,bch,xlm,bnb,xmr,xrp,usdt,link,usdc"
    static let endpoint = "cryptocurrency/quotes/latest"
    
    //Constants for individual crypto API
    static let apiKeyIndividual = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let apiHeaderIndividual = "investing-cryptocurrency-markets.p.rapidapi.com"
    static let baseURLIndividual = "https://investing-cryptocurrency-markets.p.rapidapi.com/coins/get-fullsize-chart?pair_ID="
    static let variables = "&time_utc_offset=28800&lang_ID=1&pair_interval="
}

