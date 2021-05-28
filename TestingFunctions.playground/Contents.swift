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
