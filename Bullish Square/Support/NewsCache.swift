//
//  NewsCache.swift
//  Bullish Square
//
//  Created by Javier Gomez on 4/14/26.
//

import UIKit

class NewsCache {
    static let shared = NewsCache()
    private init() {}
    
    private var data: [String: [NewsItem]] = [:]
    private var fetchedAt: [String: Date] = [:]  // ← per category
    
    func isStale(_ category: String) -> Bool {
        guard let date = fetchedAt[category] else { return true }
        return Date().timeIntervalSince(date) > 300 // 5 min
    }
    
    func store(category: String, items: [NewsItem]) {
        data[category] = items
        fetchedAt[category] = Date()
    }
    
    func get(_ category: String) -> [NewsItem]? {
        data[category]
    }
    
    func clear() {
        data = [:]
        fetchedAt = [:]
    }
}
