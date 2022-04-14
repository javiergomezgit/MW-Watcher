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
        "^IXIC" : ["Nasdaq Composite", 0.0, 0.0],
        "^W5000" : ["Wilshire 5000 Total Market Index", 0.0, 0.0],
        "^RUA" : ["Russell 3000", 0.0, 0.0],
        "^SP400" : ["S&P 400", 0.0, 0.0],
        "^RUT" : ["Russell 2000", 0.0, 0.0],
        "^VIX" : ["CBOE Volatility Index", 0.0, 0.0]
    ]
    
    /*
     let headers = [
         "X-RapidAPI-Host": "mboum-finance.p.rapidapi.com",
         "X-RapidAPI-Key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148"
     ]

     let request = NSMutableURLRequest(url: NSURL(string: "https://mboum-finance.p.rapidapi.com/hi/history?symbol=%5EDJI&interval=5m&diffandsplits=false")! as URL,
                                             cachePolicy: .useProtocolCachePolicy,
                                         timeoutInterval: 10.0)
     */
    
    var marketNames = ["^DJI","^GSPC","^IXIC","^W5000","^RUA","^SP400","^RUT","^VIX"]
    
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
        
        StocksAPI.shared.getPriceGeneralMarkets { markets in
            if markets == nil {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
            } else {
                let marketsValues = markets!
                for market in marketsValues {
                    self.marketsPrices[market.indexTicker] = [market.indexName, market.indexPrice, market.changePercentage]
                }
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.collectionView.reloadData()
                }
            }
        }
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
                
                cell.arrowImage.image = (UIImage.init(named: "arrow.down.app.fill"))
                cell.arrowImage.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            } else {
                //positive day for market
                let percentageRounded = round(100*percentageChanged)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                cell.arrowImage.image = (UIImage.init(named: "arrow.up.square.fill"))
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
