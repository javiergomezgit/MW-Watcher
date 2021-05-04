import UIKit
let tickerValue = "HD0.24%"

print (isTickerPositive(tickerValue: tickerValue))

func isTickerPositive(tickerValue: String) -> Bool {
    print (tickerValue)
    
    if tickerValue.contains("-") {
        print ("dropped")
    } else {
        print ("positive")
    }
    
    return true
}
