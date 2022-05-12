//
//  MarketsWatcherController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import Charts

class MarketsController: UIViewController {

    let refreshControl = UIRefreshControl()
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var chartView: UIView!
    
    var sizeOfCell = CGFloat(0)

    private var marketsData: [[MarketsCandles]] = [[]]
    var linearValues = [ChartDataEntry]()
    
    //MARK: Linear Chart
    lazy var lineChartViewSP500: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = true
        lineChartView.doubleTapToZoomEnabled = true
        lineChartView.dragXEnabled = true
        lineChartView.autoScaleMinMaxEnabled = true
        lineChartView.legend.enabled = false
        
        lineChartView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.rightAxis.labelTextColor = .label
        lineChartView.rightAxis.spaceTop = 0.3
        lineChartView.rightAxis.spaceBottom = 0.3
        lineChartView.rightAxis.setLabelCount(8, force: true)
        lineChartView.rightAxis.axisLineColor = .label
        lineChartView.rightAxis.labelPosition = .outsideChart
        
        lineChartView.xAxis.enabled = true
        lineChartView.xAxis.labelPosition = .top
        lineChartView.xAxis.yOffset = 10
        lineChartView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.xAxis.labelTextColor = .label
        lineChartView.xAxis.setLabelCount(4, force: true)
        
        return lineChartView
    }()
    
    lazy var lineChartViewDJI: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = true
        lineChartView.doubleTapToZoomEnabled = true
        lineChartView.dragXEnabled = true
        lineChartView.autoScaleMinMaxEnabled = true
        lineChartView.legend.enabled = false
        
        lineChartView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.rightAxis.labelTextColor = .label
        lineChartView.rightAxis.spaceTop = 0.3
        lineChartView.rightAxis.spaceBottom = 0.3
        lineChartView.rightAxis.setLabelCount(8, force: true)
        lineChartView.rightAxis.axisLineColor = .label
        lineChartView.rightAxis.labelPosition = .outsideChart
        
        lineChartView.xAxis.enabled = true
        lineChartView.xAxis.labelPosition = .top
        lineChartView.xAxis.yOffset = 10
        lineChartView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.xAxis.labelTextColor = .label
        lineChartView.xAxis.setLabelCount(4, force: true)
        
        return lineChartView
    }()
    

    
//    var marketsPrices = [
//        GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^GSPC", indexName: "S&P 500", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^IXIC", indexName: "Nasdaq Composite", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^W5000", indexName: "Wilshire 5000 Total Market Index", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^RUA", indexName: "Russell 3000", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^SP400", indexName: "S&P 400", indexPrice:  0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker: "^RUT", indexName: "Russell 2000", indexPrice: 0.0, changePercentage: 0.0),
//        GeneralMarkets(indexTicker:  "^VIX", indexName: "CBOE Volatility Index", indexPrice:  0.0, changePercentage: 0.0)
//    ]
    
    var mayorMarketsPrices = [GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0)]
    
    var minorMarketPrices : [GeneralMarkets] = []
//     var minorMarketPrices = [GeneralMarkets(indexTicker: "^IXIC", indexName: "Nasdaq Composite", indexPrice: 0.0, changePercentage: 0.0)]
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadMayorMarketsChart()
        
        loadCurrentPrices()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        collectionView.addSubview(refreshControl) // not required when using UITableViewController
        
        sizeOfCell = (view.frame.width/3) - (view.frame.width/20)
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
                self.mayorMarketsPrices.removeAll()
                self.minorMarketPrices.removeAll()
                
                self.loadMayorMarkets(marketsValues: marketsValues)
                self.loadMinorMarkets(marketsValues: marketsValues)
                
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func loadMayorMarkets(marketsValues: [GeneralMarkets]){
        
        for market in marketsValues {
            let ticker = market.indexTicker
            if ticker == "^DJI" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "DOW JONES", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.mayorMarketsPrices.append(newName)
            }
            if ticker == "^GSPC" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "S&P 500", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.mayorMarketsPrices.append(newName)
            }
            if ticker == "^IXIC" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "NASDAQ", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.mayorMarketsPrices.append(newName)
            }
        }
    }
    
    func loadMinorMarkets(marketsValues: [GeneralMarkets]){
        for market in marketsValues {
            let ticker = market.indexTicker
            if ticker == "^VIX" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "CBOE Volatility Index", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^RUT" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Russell 2000", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^SP400" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "S&P 400", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^RUA" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Russell 3000", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^W5000" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Wilshire 5000 Total Market Index", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
        }
    }
}

extension MarketsController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mayorMarketsPrices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MarketCell", for: indexPath) as! MarketsViewCell
        
        let tickerValues = mayorMarketsPrices[indexPath.row]

        cell.nameLabel.text = tickerValues.indexName.uppercased()
    
        var currentPrice = tickerValues.indexPrice
        let percentageChanged = tickerValues.changePercentage
            
            if percentageChanged < 0 {
                let percentageRounded = round(100*percentageChanged)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                
                cell.arrowImageView.image = (UIImage.init(named: "arrow.down.app.fill"))
                cell.arrowImageView.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            } else {
                //positive day for market
                let percentageRounded = round(100*percentageChanged)/100
                cell.changeLabel.text = String(percentageRounded) + "%"
                cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                currentPrice = round(100*currentPrice)/100
                cell.currentPriceLabel.text = "$ " + String(currentPrice)
                cell.currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                
                cell.arrowImageView.image = (UIImage.init(named: "arrow.up.square.fill"))
                cell.arrowImageView.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            }
            
            cell.openChartButton.tag = indexPath.row
            cell.openChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func openChart(sender: UIButton) {
        let ticker = self.mayorMarketsPrices[sender.tag]
        
        let perChange = ticker.changePercentage
        let percentageRounded = round(100*perChange)/100
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = TickersCurrentValues(ticker: ticker.indexTicker, marketPrice: ticker.indexPrice, previousPrice: 0.0, changePercent: percentageRounded)
        destination!.informationStockTicker = tickerWithChange
        destination!.indexName = ticker.indexName
        destination!.indexMarket = true
        
        destination!.modalPresentationStyle = .popover
        destination!.modalTransitionStyle = .crossDissolve
        
        self.present(destination!, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: sizeOfCell, height: (sizeOfCell * 0.80))
    }
}




extension MarketsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return minorMarketPrices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MinorMarketsViewCell", for: indexPath) as! MinorMarketsViewCell

        
        let ticker = minorMarketPrices[indexPath.row].indexTicker
        let name = minorMarketPrices[indexPath.row].indexName
        let image = UIImage(named: "mw-logo")
        
        let marketPrice = minorMarketPrices[indexPath.row].indexPrice
        var percentage = minorMarketPrices[indexPath.row].changePercentage
        percentage = Double(round(100*percentage)/100)
        
        cell.tickerLabel.text = ticker.replacingOccurrences(of: "^", with: "")
        cell.currentPriceLabel.text = "$\(marketPrice)"
        cell.imageCompanyImageView.image = image
        cell.nameCompanyLabel.text = name
        cell.changeLabel.text = String(percentage) + "%"
        
        if percentage < 0 {
            cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            cell.arrowImageView.image = (UIImage.init(systemName: "arrow.down.app.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            cell.frameCoverLabel.backgroundColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1)
        } else {
            cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            cell.arrowImageView.image = (UIImage.init(systemName: "arrow.up.square.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            cell.frameCoverLabel.backgroundColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 0.7)
        }
        
        cell.openChartButton.tag = indexPath.row
        cell.openChartButton.addTarget(self, action: #selector(openChartMinorMarket(sender:)), for: .touchUpInside)
              
        return cell
    }
    
    @objc func openChartMinorMarket(sender: UIButton) {
        let ticker = self.minorMarketPrices[sender.tag]
        
        let perChange = ticker.changePercentage
        let percentageRounded = round(100*perChange)/100
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = TickersCurrentValues(ticker: ticker.indexTicker, marketPrice: ticker.indexPrice, previousPrice: 0.0, changePercent: percentageRounded)
        destination!.informationStockTicker = tickerWithChange
        destination!.indexName = ticker.indexName
        destination!.indexMarket = true
        
        destination!.modalPresentationStyle = .popover
        destination!.modalTransitionStyle = .crossDissolve
        
        self.present(destination!, animated: true, completion: nil)
    }
}




extension MarketsController: ChartViewDelegate {
    
    
    func loadMayorMarketsChart() {

            ChartsAPI.shared.getMayorMarketsValues { result in
                switch result {
                case .success(let marketsValues):
                    
                    self.marketsData = marketsValues
                    
                    DispatchQueue.main.async {
//                        self?.startStopSpinner(start: false)
                        self.setUpMarketModel()
                    }
                    
                case .failure(_):
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                }
            }

    }
    private func setUpMarketModel(){
        guard let modelCandles = marketsData.first else { return }

        self.linearValues.removeAll()
        
        for (index, candleValue) in modelCandles.enumerated() {
//            let startingAt = candleValue.start_timestamp
//            let openPrice = candleValue.open
//            let highPrice = candleValue.high
            let closePrice = candleValue.close
//            let lowPrice = candleValue.low
            
            let linearValueEntry = ChartDataEntry(x: Double(index), y: closePrice)
            
            self.linearValues.append(linearValueEntry)
        }
        
        setupLineChart()
        
    }
    
    
    func setupLineChart(){
        chartView.addSubview(lineChartViewSP500)
        lineChartViewSP500.centerInSuperview()
        lineChartViewSP500.width(to: chartView)
        lineChartViewSP500.height(to: chartView)
        
        setDataSP500()
    }
    
    func setDataSP500() {
        let set1 = LineChartDataSet(entries: linearValues, label: "Subscribs")
        
        set1.mode = .linear//.cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 2
        set1.setColor(.yellow)
//        let v1 = linearValues.first!.y
//        let v2 = linearValues.last!.y
//        if v1 < v2 {
//            set1.setColor(UIColor(named: "uptrend")!)
//            set1.fill = Fill(color: UIColor(named: "uptrend")!)
//            set1.fillAlpha = 0.1
//        } else {
//            set1.setColor(.red.withAlphaComponent(0.7))
//            set1.fill = Fill(color: .red)
//            set1.fillAlpha = 0.2
//        }
        
        set1.drawFilledEnabled = false
        
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightColor = .systemRed
        
        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        lineChartViewSP500.data = data
    }
    

}
