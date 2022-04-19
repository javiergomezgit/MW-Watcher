import UIKit
//let tickerValue = "HD0.24%"
//
////print (isTickerPositive(tickerValue: tickerValue))
//
//func isTickerPositive(tickerValue: String) -> Bool {
//    print (tickerValue)
//
//    if tickerValue.contains("-") {
//        print ("dropped")
//    } else {
//        print ("positive")
//    }
//
//    return true
//}
//
//let headli = "Sen. Rand Paul says he’ll skip COVID vaccine for now, will rely on ‘natural immunity’"
//let charArr1 = [Character](headli)
//
//let csd = Array(headli)
//
//
//let tosd = headli.components(separatedBy: "and")
//let oosd = headli.components(separatedBy: " ")
//let so = headli.wordList
//
//
//
//extension String {
//    var wordList: [String] {
//        return components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
//    }
//}
//
//print (clean(head: so))
//
//func clean(head: [String]) -> String {
//    var cleanArray = ""
//
//    for hea in head {
//        if hea != "of" &&
//            hea != "a" &&
//            hea != "an" &&
//            hea != "as" &&
//            hea != "so" &&
//            hea != "and" &&
//            hea != "the" &&
//            hea != "and" &&
//            hea != "or" &&
//            hea != "for" &&
//            hea != "to" &&
//            hea != "from" &&
//            hea != "on" &&
//            hea != "its" &&
//            hea != "it" &&
//            hea != "to" &&
//            hea != "this" &&
//            hea != "in" &&
//            hea != "of" &&
//            hea != "is"  {
//            cleanArray = cleanArray + " " + hea
//        }
//
//    }
//
//    return cleanArray
//}


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



//let dateString = "2021-06-08T08:01:00.0000000Z"
//
//let date = dateString.components(separatedBy: ".")
//
//let dateFormatterGet = DateFormatter()
//dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
//dateFormatterGet.timeZone = TimeZone(identifier: "CDT")
//
//   let dateFormatter = DateFormatter()
//dateFormatter.dateStyle = .medium
//dateFormatter.timeStyle = .medium
//dateFormatter.timeZone = TimeZone(identifier: "PDT")//NSTimeZone(name: "America/Los_Angeles") as TimeZone?
//
//   let dateObj: Date? = dateFormatterGet.date(from: date[0] + "Z")
//
//   let some = dateFormatter.string(from: dateObj!)
//
//print (some)


//let dateString = "2022-04-01 15:30:00 UTC"
let dateFormat =  "yyyy/MM"
let time = 1648138500.0
let date = Date(timeIntervalSince1970: time)

let dateFormatter = DateFormatter()
dateFormatter.timeZone = TimeZone(abbreviation: "PST") //Set timezone that you want
dateFormatter.locale = NSLocale.current
dateFormatter.dateFormat = dateFormat //Specify your format that you want
let strDate = dateFormatter.string(from: date)

print (strDate)
