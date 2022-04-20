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
        GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^GSPC", indexName: "S&P 500", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^IXIC", indexName: "Nasdaq Composite", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^W5000", indexName: "Wilshire 5000 Total Market Index", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^RUA", indexName: "Russell 3000", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^SP400", indexName: "S&P 400", indexPrice:  0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker: "^RUT", indexName: "Russell 2000", indexPrice: 0.0, changePercentage: 0.0, exchange: ""),
        GeneralMarkets(indexTicker:  "^VIX", indexName: "CBOE Volatility Index", indexPrice:  0.0, changePercentage: 0.0, exchange: "")
    ]
    
    var selectedIndex = ""
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
    }
    
    func loadCurrentPrices() {
        
        StocksAPI.shared.getPriceGeneralMarkets { markets in
            if markets == nil {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
            } else {
                let marketsValues = markets!
                self.marketsPrices.removeAll()
                for market in marketsValues {
                    self.marketsPrices.append(market)
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
        
        let tickerValues = marketsPrices[indexPath.row]

        cell.nameLabel.text = tickerValues.indexName
            
        var currentPrice = tickerValues.indexPrice
        let percentageChanged = tickerValues.changePercentage
            
            if percentageChanged < 0 {
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
            
            cell.openChartButton.tag = indexPath.row
            cell.openChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func openChart(sender: UIButton) {
        let ticker = self.marketsPrices[sender.tag]
        
        let perChange = ticker.changePercentage
        let percentageRounded = round(100*perChange)/100
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = Tickers(ticker: ticker.indexTicker, marketPrice: ticker.indexPrice, previousPrice: percentageRounded)
        destination?.informationStockTicker = tickerWithChange
        destination?.indexName = ticker.indexName
        destination?.indexMarket = true
        
        self.show(destination!, sender: self)
    }
}

extension MarketsController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: sizeOfCell, height: sizeOfCell)
    }
}
