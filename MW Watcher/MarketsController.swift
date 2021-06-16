//
//  MarketsWatcherController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit

class MarketsController: UIViewController {

    let refreshControl = UIRefreshControl()
    @IBOutlet weak var collectionView: UICollectionView!
    var sizeOfCell = CGFloat(0)
    
    var marketsPrices = [
        "^DJI" : ["Dow Jones Industrial Average", 0.0, 0.0],
        "^GSPC" : ["S&P 500", 0.0, 0.0],
        "NDAQ" : ["Nasdaq, Inc.", 0.0, 0.0],
        "^W5000" : ["Wilshire 5000 Total Market Index", 0.0, 0.0],
        "^RUA" : ["Russell 3000", 0.0, 0.0],
        "^SP400" : ["S&P 400", 0.0, 0.0],
        "^RUT" : ["Russell 2000", 0.0, 0.0],
        "^VIX" : ["CBOE Volatility Index", 0.0, 0.0]
    ]
    
    var marketNames = ["^DJI","^GSPC","NDAQ","^W5000","^RUA","^SP400","^RUT","^VIX"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadCurrentPrices()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        collectionView.addSubview(refreshControl) // not required when using UITableViewController
        
        sizeOfCell = (view.frame.width/2) - (view.frame.width/20)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadCurrentPrices()
        //tableView.reloadData()
    }
    
    func loadCurrentPrices() {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "yahoo-finance-low-latency.p.rapidapi.com"
        ]

        let request = NSMutableURLRequest(url: NSURL(string: "https://yahoo-finance-low-latency.p.rapidapi.com/v6/finance/quote?symbols=%5EDJI%2C%5EGSPC%2CNDAQ%2C%5EW5000%2C%5ERUA%2C%5ESP400%2C%5ERUT%2C%5EVIX&lang=en&region=US")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
            } else {
                //let httpResponse = response as? HTTPURLResponse
                //print(httpResponse)
                
                let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                print (json!)
                
                let resultJSON = json?["quoteResponse"] as? [String: Any]
                
                if let resultArray = resultJSON!["result"] as? [Any] {

                    for tickerJSON in resultArray {
                        
                        let tickerDictionary = tickerJSON as? [String: Any]
                        
                        
                        let marketPrice = tickerDictionary!["regularMarketPrice"] as! Double
                        let changePercentage = tickerDictionary!["regularMarketChangePercent"] as! Double
                        let ticker = tickerDictionary!["symbol"] as! String

                        let marketsNameValues = self.marketsPrices[ticker]
                        let nameOfMarket = marketsNameValues![0]

                        self.marketsPrices[ticker] = [nameOfMarket, marketPrice, changePercentage]
                    }
                    
                    print (self.marketsPrices)
                    DispatchQueue.main.async {
                        self.refreshControl.endRefreshing()
                        self.collectionView.reloadData()
                    }

                } else {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                }
            }
        })

        dataTask.resume()
    }
}



extension MarketsController: UICollectionViewDelegate, UICollectionViewDataSource {
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
            let percentageChanged = tickerInfo[2] as! Double
            
            if percentageChanged < 0 {
                //negative day for market
                let percentageRounded = round(100*percentageChanged)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                
                cell.arrowImage.image = (UIImage.init(systemName: "arrow.down.app.fill"))
                cell.arrowImage.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            } else {
                //positive day for market
                let percentageRounded = round(100*percentageChanged)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                cell.arrowImage.image = (UIImage.init(systemName: "arrow.up.square.fill"))
                cell.arrowImage.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            }

        }
        return cell
    }
}

extension MarketsController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: sizeOfCell, height: sizeOfCell)
    }
}
