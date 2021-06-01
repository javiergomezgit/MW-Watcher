//
//  MarketsWatcherController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit

class MarketsWatcherController: UIViewController {

    let refreshControl = UIRefreshControl()
    @IBOutlet weak var collectionView: UICollectionView!

    var marketsPrices = [
        "^DJI" : ["Dow Jones Industrial Average", 0.0, 0.0],
        "^GSPC" : ["S&P 500", 0.0, 0.0],
        "NDAQ" : ["Nasdaq, Inc.", 0.0, 0.0],
        "^W5000" : ["Wilshire 5000 Total Market Index", 0.0, 0.0],
        "^RUA" : ["Russell 3000", 0.0, 0.0],
        "^SP400" : ["S&P 400", 0.0, 0.0],
        "^RUT" : ["Russell 2000", 0.0, 0.0],
        "BTC-USD" : ["Bitcoin USD", 0.0, 0.0],
        "^VIX" : ["CBOE Volatility Index", 0.0, 0.0]
    ]
    
    var marketNames = ["^DJI","^GSPC","NDAQ","^W5000","^RUA","^SP400","^RUT","BTC-USD","^VIX"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadCurrentPrices()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        collectionView.addSubview(refreshControl) // not required when using UITableViewController
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadCurrentPrices()
        //tableView.reloadData()
    }
    
    
    func loadCurrentPrices() {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url: NSURL(string: "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=%5EDJI%2C%5EGSPC%2CNDAQ%2C%5EW5000%2C%5ERUA%2C%5ESP400%2C%5ERUT%2CBTC-USD%2C%5EVIX&interval=1d&range=1d")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error!)
            } else {
                let httpResponse = response as? HTTPURLResponse
                print (httpResponse!)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                print (json!)
                
                for tickerJSON in json! {
                    print (tickerJSON.value) //json values prices etc
                    print (tickerJSON.key) //ticker
                    
                    let tickerDictionary = tickerJSON.value as? [String: Any]
                    
                    let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                    
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    
                    let currentPrice = closePriceArray!.first as! Double
                    
                    let marketsNameValues = self.marketsPrices[tickerJSON.key]
                    let nameOfMarket = marketsNameValues![0]
                    
                    self.marketsPrices[tickerJSON.key] = [nameOfMarket, currentPrice, previousClose]
                }
                print (self.marketsPrices)
                
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.collectionView.reloadData()
                }
            }
        })

        dataTask.resume()
    }
}



extension MarketsWatcherController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return marketNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MarketCell", for: indexPath) as! MarketsViewCell
        
        let ticker = marketNames[indexPath.row]
        if let tickerInfo = marketsPrices[ticker] {
            print (tickerInfo)
            cell.tickerLabel.text = ticker
            cell.nameLabel.text = tickerInfo[0] as? String
            
            var currentPrice = tickerInfo[1] as! Double
            let previousPrice = tickerInfo[2] as! Double
            let changePercentage = (currentPrice * 100) / previousPrice
            if changePercentage < 100 {
                //negative day for market
                var percentageRounded = 100 - changePercentage
                percentageRounded = round(100*percentageRounded)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            } else {
                //positive day for market
                var percentageRounded = changePercentage - 100
                percentageRounded = round(100*percentageRounded)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            }
        }
        return cell
    }
    
}
