import UIKit
let tickerValue = "HD0.24%"

//print (isTickerPositive(tickerValue: tickerValue))

func isTickerPositive(tickerValue: String) -> Bool {
    print (tickerValue)
    
    if tickerValue.contains("-") {
        print ("dropped")
    } else {
        print ("positive")
    }
    
    return true
}

let headli = "Sen. Rand Paul says he’ll skip COVID vaccine for now, will rely on ‘natural immunity’"
let charArr1 = [Character](headli)

let csd = Array(headli)


let tosd = headli.components(separatedBy: "and")
let oosd = headli.components(separatedBy: " ")
let so = headli.wordList



extension String {
    var wordList: [String] {
        return components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}

print (clean(head: so))

func clean(head: [String]) -> String {
    var cleanArray = ""
    
    for hea in head {
        if hea != "of" &&
            hea != "a" &&
            hea != "an" &&
            hea != "as" &&
            hea != "so" &&
            hea != "and" &&
            hea != "the" &&
            hea != "and" &&
            hea != "or" &&
            hea != "for" &&
            hea != "to" &&
            hea != "from" &&
            hea != "on" &&
            hea != "its" &&
            hea != "it" &&
            hea != "to" &&
            hea != "this" &&
            hea != "in" &&
            hea != "of" &&
            hea != "is"  {
            cleanArray = cleanArray + " " + hea
        }
        
    }
    
    return cleanArray
}


/*
// MARK: - Ticker
struct Ticker: Codable {
    let chart: Chart
}

// MARK: - Chart
struct Chart: Codable {
    let result: [Result]?
    let error: Description?
}

struct Description: Codable {
    let description: String
}

// MARK: - Result
struct Result: Codable {
    let meta: Meta
}

struct Meta: Codable {
    let regularMarketPrice: Double
    let chartPreviousClose: Double
}

// MARK: - Ticker
struct Ticker: Codable {
    let quoteResponse: QuoteResponse
}

// MARK: - QuoteResponse
struct QuoteResponse: Codable {
    let result: [Result]
}

// MARK: - Result
struct Result: Codable {

    let postMarketChangePercent: Double
    let postMarketPrice: Double
    let longName: String
    let regularMarketPrice: Double
}

// MARK: - Ticker
struct Ticker: Codable {
    let chart: Chart
}

// MARK: - Chart
struct Chart: Codable {
    let result: [Result]?
    let error: Description?
}

struct Description: Codable {
    let description: String
}

// MARK: - Result
struct Result: Codable {
    let meta: Meta
}

struct Meta: Codable {
    let regularMarketPrice: Double
    let chartPreviousClose: Double
}

struct Tickers {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
}
*/
