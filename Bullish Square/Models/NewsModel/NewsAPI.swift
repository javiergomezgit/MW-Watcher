//
//  NewsAPI.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/6/22.
//


import Foundation

enum KeysNewsCallAPI {
    
    //Constants for search/add of single stock
    static let loadNewsKey = "4a91f1240591787212f13963728551c2"
    static let apiHost = "stock-data-yahoo-finance-alternative.p.rapidapi.com"
    static let loadNewsbaseUrl = "https://gnews.io/api/v4/top-headlines?"
    
    //Constants for load news about an specific stock
    static let loadStockNewsKey = "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
    static let loadStockNewsHost = "cnbc.p.rapidapi.com"
    static let loadStockNewsbaseUrl = "https://cnbc.p.rapidapi.com/news/v2/list-by-symbol?page=1&pageSize=5&symbol="
    
    //Constants for ElevenLabs text-to-speech
    static let  elevenLabsAPIKey = "sk_c40b38111327abc20914168ed026003eedf486e1d30922c0"
    static let elevenLabsBaseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    static let voiceID = "21m00Tcm4TlvDq8ikWAM" // Rachel
    
}
