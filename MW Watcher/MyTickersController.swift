//
//  MyTickersController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import Foundation

struct Tickers {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
}

class MyTickersController: UIViewController {

    @IBOutlet var tableView: UITableView!
    @IBOutlet var tickerToAddText: UITextField!
    
    var tickers: [Tickers] = []
    var timeRange: String = "&interval=1d&range=2d"
    let savedTickers = SaveMyTickers()

    @IBAction func chosingTime(_ sender: UISegmentedControl) {
        
        switch sender.selectedSegmentIndex {
        case 0:
            timeRange = "&interval=1d&range=1d"
        case 1:
            timeRange = "&interval=1w&range=2w"
        case 2:
            timeRange = "month"
        default:
            break
        }
    }
    
    func loadTicker(loadSingle: String?, loadMultiple: [String]?) {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
        ]
        
        var ticker = ""
        var url = ""
        var json: [String: Any]? = [:]
        
        if loadSingle != nil {
            ticker = loadSingle!
            url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + ticker + timeRange
        } else {
            for singleTicker in loadMultiple! {
                ticker = ticker + "%2C" + singleTicker
            }
            url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + ticker + timeRange
        }
        
        print (url)

        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error)
            } else {
                //let httpResponse = response as? HTTPURLResponse
                json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                
                if let tickerFound = json![ticker] {
                    //SINGLE TICKER
                    let tickerDictionary = tickerFound as? [String: Any]
                    let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray![0] as! Double
                    
                    self.savedTickers.saveTicker(ticker: ticker)
                    self.tickers.append(Tickers(ticker: ticker, marketPrice: closePrice, previousPrice: previousClose))
                    print (self.tickers)
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                    
                } else {
                    //MULTIPLE TICKER
                    if loadMultiple != nil {
                        for tickFound in json! {
                            print (tickFound.value) //json
                            print (tickFound.key) //ticker
                            
                            let tickerDictionary = tickFound.value as? [String: Any]
                            let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                            let closePriceArray = tickerDictionary!["close"] as? [Any]
                            let closePrice = closePriceArray![0] as! Double
                            
                            self.tickers.append(Tickers(ticker: tickFound.key, marketPrice: closePrice, previousPrice: previousClose))
                        }
                        print (self.tickers)
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    } else  {
                        print ("ticker not found")
                        self.tickerToAddText.text = ""
                    }
                }
            }
        })
        dataTask.resume()
    }

    @IBAction func addingTicker(_ sender: UIButton) {
        
        if !tickerToAddText.text!.isEmpty {
            loadTicker(loadSingle: tickerToAddText.text!, loadMultiple: nil)
        } else {
            print ("empty ticker")
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let savedTickers = savedTickers.loadTickers()
        
        if !savedTickers.isEmpty {
            loadTicker(loadSingle: nil, loadMultiple: savedTickers)
        }
        
        //TODO: load saved tickers - depending on segmented bar
        //TODO: refresh table every view again
    }
}

extension MyTickersController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "myTickersCell", for: indexPath) as! MyTickersViewCell
        cell.tickerLabel.text = tickers[indexPath.row].ticker
        cell.currentPriceLabel.text = "$" + String(tickers[indexPath.row].marketPrice)
        
        let percentageChange = (tickers[indexPath.row].marketPrice * 100) / tickers[indexPath.row].previousPrice
        if percentageChange < 100 {
            var percentageRounded = 100 - percentageChange
            percentageRounded = Double(round(100*percentageRounded)/100)
            cell.changeLabel.text = "- " + String(percentageRounded) + " %"
            cell.changeLabel.textColor = UIColor.red
            
            let previousPrice = Double(round(100*tickers[indexPath.row].previousPrice)/100)
            cell.previousPriceLabel.text = "Previous $" + String(previousPrice)
            cell.previousPriceLabel.textColor = UIColor.red
        } else {
            var percentageRounded = percentageChange - 100
            percentageRounded = Double(round(100*percentageRounded)/100)
            cell.changeLabel.text = "+ " + String(percentageRounded) + " %"
            cell.changeLabel.textColor = UIColor.blue
            
            let previousPrice = Double(round(100*tickers[indexPath.row].previousPrice)/100)
            cell.previousPriceLabel.text = "Previous $" + String(previousPrice)
            cell.previousPriceLabel.textColor = UIColor.blue
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
            return .delete
        }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let ticker = tickers[indexPath.row].ticker
            savedTickers.deleteTickers(ticker: ticker, deleteAll: false)
            
            tickers.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
           
        }
    }
}




//for the day checking
//let request = NSMutableURLRequest(url: NSURL(string: "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=aapl&interval=1d&range=2d")! as URL,
//for the month
//let request = NSMutableURLRequest(url: NSURL(string: "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=aapl&interval=1mo&range=1mo")! as URL,

//more info
//let request = NSMutableURLRequest(url: NSURL(string: "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/v2/get-quotes?region=US&symbols=aapl")! as URL,


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
