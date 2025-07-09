//
//  SimulatedPortfolioController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 3/25/23.
//

import UIKit
import DGCharts
//import TinyConstraints

class SimulatedPortfolioController: UIViewController {
    
    
    @IBOutlet weak var dateTodayLabe: UILabel!
    @IBOutlet weak var sp500TodayLabel: UILabel!
    @IBOutlet weak var dowTodayLabel: UILabel!
    @IBOutlet weak var nasdaqTodayLabel: UILabel!
    
    @IBOutlet weak var sp500ComparingLabel: UILabel!
    @IBOutlet weak var sp500OverLabel: UILabel!
    @IBOutlet weak var dowComparingLabel: UILabel!
    @IBOutlet weak var dowOverLabel: UILabel!
    @IBOutlet weak var nasdaqComparingLabel: UILabel!
    @IBOutlet weak var nasdaqOverLabel: UILabel!
    @IBOutlet weak var myPortfolioOverLabel: UILabel!
    @IBOutlet weak var myPortfolioComparingLabel: UILabel!
    
    @IBOutlet weak var chartView: UIView!
    
    @IBOutlet weak var timesSegmentedControl: HBSegmentedControl!
    
    var marketsPrices = [GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0)]
    let savedTickers = SaveTickers()
    var vixTodayPrice = 0.0
    var nasdaqTodayPrice = 0.0
    var sp500TodayPrice = 0.0
    var dowTodayPrice = 0.0
    var timeRange = "&interval=15m&range=1d"
    
    private var linearValuesSP500 = [ChartDataEntry]()
    private var linearValuesDJI = [ChartDataEntry]()
    private var linearValuesIXIC = [ChartDataEntry]()
    private var linearValuesPortfolio = [ChartDataEntry]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setSegementedControl()
        
        if let tickers = loadPortfolioTickers() {
            loadCurrentPrices(tickers: tickers)
        }
            
        loadDate()
    }
    
    private func loadDate() {
        let currentDateTime = Date()
//        let userCalendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale.current
        let dateMerged = dateFormatter.string(from: currentDateTime)
        dateTodayLabe.text = "U.S. Markets - \(dateMerged)"
    }
    
    private func setSegementedControl() {
        timesSegmentedControl.borderColor = .systemGray6
        timesSegmentedControl.selectedLabelColor = .systemBackground
        timesSegmentedControl.unselectedLabelColor = .label.withAlphaComponent(0.8)
        timesSegmentedControl.backgroundColor = .systemGray3
        timesSegmentedControl.thumbColor = .label
        timesSegmentedControl.selectedIndex = 0
        timesSegmentedControl.items = ["1 day", "1 month", "1 year", "5 years"]
        timesSegmentedControl.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)
    }
    
    @objc func segmentValueChanged(_ sender: AnyObject?){
        
        startStopSpinner(start: true)
        
        let index = timesSegmentedControl.selectedIndex
        
        switch index {
        case 0: timeRange = "&interval=15m&range=1d"
            break
        case 1: timeRange = "&interval=1d&range=1mo"
            break
        case 2: timeRange = "&interval=1wk&range=1y"
            break
        default:
            timeRange = "&interval=1mo&range=5y"
        }
        if let tickers = loadPortfolioTickers() {
            loadCurrentPrices(tickers: tickers)
        }
    }
    
    let child = Spinner()
    func startStopSpinner(start: Bool){
        if start {
            addChild(child)
            child.view.frame = view.frame
            view.addSubview(child.view)
            child.didMove(toParent: self)
        } else {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    //Return string made of the merged saved tickers
    func loadPortfolioTickers() -> String? {
        let tickers = self.savedTickers.loadTickers()
        
        var mergedTickers = ""
        if !tickers.isEmpty {
            for (index, savedTicker) in tickers.enumerated() {
                let ticker = savedTicker.ticker
                if index == 0 {
                    mergedTickers = ticker
                } else {
                    mergedTickers = mergedTickers + "%2C" + ticker
                }
            }
        } else {
            return nil
        }
        return mergedTickers
    }
    
    func loadCurrentPrices(tickers: String) {
        ChartAPI.shared.getPricesMarketsAndWatchlist(tickersWatchlist: tickers, timeRange: timeRange) { markets in
            if markets == nil {
                self.startStopSpinner(start: false)
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
            } else {
                guard let marketsValues = markets else {
                    self.startStopSpinner(start: false)
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                    return
                }
                self.linearValuesSP500.removeAll()
                self.linearValuesDJI .removeAll()
                self.linearValuesIXIC.removeAll()
                self.linearValuesPortfolio.removeAll()
                DispatchQueue.main.async {
                    print (marketsValues)
                    self.startStopSpinner(start: false)
                    self.processPricesPerformance(marketsValues: marketsValues)
                }
            }
        }
    }
    
    func processPricesPerformance(marketsValues: [PerformersPrices]){
        
        var sumPortfolio = 0.0
        var pricesAndTimes = [PerformersPrices]()
        
        for marketValue in marketsValues {

            let ticker = marketValue.ticker
            switch ticker {
            case "^DJI":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "DOW JONES", indexPrice: market., changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.dowTodayPrice = percentage
                dowTodayLabel.text = String("\(percentage)%")
                for (index, lineValue) in marketValue.tickerPerformer.enumerated() {
                    let closePrice = lineValue.close
                    self.linearValuesDJI.append(ChartDataEntry(x: Double(index), y: closePrice))
                }
                break
            case "^GSPC":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "S&P 500", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.sp500TodayPrice = percentage
                sp500TodayLabel.text = String("\(percentage)%")
                for (index, lineValue) in marketValue.tickerPerformer.enumerated() {
                    let closePrice = lineValue.close
                    self.linearValuesSP500.append(ChartDataEntry(x: Double(index), y: closePrice))
                }
                break
            case "^IXIC":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "NASDAQ", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.nasdaqTodayPrice = percentage
                nasdaqTodayLabel.text = String("\(percentage)%")
                for (index, lineValue) in marketValue.tickerPerformer.enumerated() {
                    let closePrice = lineValue.close
                    self.linearValuesIXIC.append(ChartDataEntry(x: Double(index), y: closePrice))
                }
                break
            case "^VIX":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "CBOE Volatility Index", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.vixTodayPrice = percentage
                break
            default :
                sumPortfolio += marketValue.changePercentage
                pricesAndTimes.append(marketValue)
            }
        }
        
        populatePortfolioChartEntry(portfolioStocks: pricesAndTimes)
        
        sumPortfolio = sumPortfolio / Double(marketsValues.count - 4)
        
        let dowCompareTo = sumPortfolio - self.dowTodayPrice
        let sp500CompareTo = sumPortfolio - self.sp500TodayPrice
        let nasdaqCompareTo = sumPortfolio - self.nasdaqTodayPrice
        let portfolioPerformance = sumPortfolio
                
        DispatchQueue.main.async {
            if dowCompareTo < 0 {
                self.dowComparingLabel.textColor = UIColor(named: "downtrend")
                self.dowOverLabel.textColor = UIColor(named: "downtrend")
                self.dowOverLabel.text = "Underperforming the"

            } else {
                self.dowComparingLabel.textColor = UIColor(named: "uptrend")
                self.dowOverLabel.textColor = UIColor(named: "uptrend")
                self.dowOverLabel.text = "Overperforming the"

            }
            
            if sp500CompareTo < 0 {
                self.sp500ComparingLabel.textColor = UIColor(named: "downtrend")
                self.sp500OverLabel.textColor = UIColor(named: "downtrend")
                self.sp500OverLabel.text = "Underperforming the"

            } else {
                self.sp500ComparingLabel.textColor = UIColor(named: "uptrend")
                self.sp500OverLabel.textColor = UIColor(named: "uptrend")
                self.sp500OverLabel.text = "Overperforming the"

            }
            
            if nasdaqCompareTo < 0 {
                self.nasdaqComparingLabel.textColor = UIColor(named: "downtrend")
                self.nasdaqOverLabel.textColor = UIColor(named: "downtrend")
                self.nasdaqOverLabel.text = "Underperforming the"

            } else {
                self.nasdaqComparingLabel.textColor = UIColor(named: "uptrend")
                self.nasdaqOverLabel.textColor = UIColor(named: "uptrend")
                self.nasdaqOverLabel.text = "Overperforming the"

            }
            
            if portfolioPerformance < 0 {
//                self.myPortfolioComparingLabel.textColor = UIColor(named: "downtrend")
                self.myPortfolioOverLabel.textColor = UIColor(named: "downtrend")
                self.myPortfolioOverLabel.text = "Underperforming"
            } else {
//                self.myPortfolioComparingLabel.textColor = UIColor(named: "uptrend")
                self.myPortfolioOverLabel.textColor = UIColor(named: "uptrend")
                self.myPortfolioOverLabel.text = "Overperforming"
            }
            
            self.dowComparingLabel.text = String("\(Double(round(100*dowCompareTo)/100))%")
            self.sp500ComparingLabel.text = String("\(Double(round(100*sp500CompareTo)/100))%")
            self.nasdaqComparingLabel.text = String("\(Double(round(100*nasdaqCompareTo)/100))%")
            self.myPortfolioComparingLabel.text = String("\(Double(round(100*portfolioPerformance)/100))%")
            //self.refreshControl.endRefreshing()
            //self.startStopSpinner(start: false)
            self.loadPerformerChart()
        }
    }
    
    private func populatePortfolioChartEntry(portfolioStocks: [PerformersPrices]) {
        
        for (index, stock) in portfolioStocks.enumerated() {
            if index == 0 {
                for (i, closePrices) in stock.tickerPerformer.enumerated() {
                    let closePrice = closePrices.close
                    self.linearValuesPortfolio.append(ChartDataEntry(x: Double(i), y: closePrice))
                }
            } else {
                for (i, closePrices) in stock.tickerPerformer.enumerated() {
                    if i != self.linearValuesPortfolio.count {
                        let closePrice = closePrices.close
                        let previousPrice = self.linearValuesPortfolio[i].y
                        
                        let avgPercentage = (previousPrice + closePrice) / Double(portfolioStocks.count)
                        self.linearValuesPortfolio[i].y = avgPercentage
                    }
                }
            }
        }
    }
    
    lazy var lineChartView: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        
        lineChartView.dragEnabled = false
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = false
        lineChartView.doubleTapToZoomEnabled = false
        lineChartView.dragXEnabled = false
        lineChartView.autoScaleMinMaxEnabled = false  // ← CHANGED FROM true TO false
        lineChartView.legend.enabled = true
        lineChartView.legend.textColor = .label
        
        lineChartView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.rightAxis.labelTextColor = .label
        lineChartView.rightAxis.setLabelCount(6, force: false)  // ← CHANGED FROM (8, force: true) TO (6, force: false)
        lineChartView.rightAxis.axisLineColor = .label
        lineChartView.rightAxis.labelPosition = .outsideChart
        
        lineChartView.xAxis.enabled = false
        
        return lineChartView
    }()
    
    private func setAxisRange() {
        // Find the min and max values across all datasets
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        
        // Check all data arrays
        let allData = [linearValuesSP500, linearValuesDJI, linearValuesIXIC, linearValuesPortfolio]
        
        for dataArray in allData {
            for entry in dataArray {
                minValue = min(minValue, entry.y)
                maxValue = max(maxValue, entry.y)
            }
        }
        
        // Add some padding (10% on each side)
        let padding = (maxValue - minValue) * 0.1
        let adjustedMin = minValue - padding
        let adjustedMax = maxValue + padding
        
        // Set the axis range
        lineChartView.rightAxis.axisMinimum = adjustedMin
        lineChartView.rightAxis.axisMaximum = adjustedMax
    }
}

extension SimulatedPortfolioController: ChartViewDelegate {
    
    func loadPerformerChart() {
        var centerLineData = [ChartDataEntry]()
        for index in 0...linearValuesDJI.count { //78
            centerLineData.append(ChartDataEntry(x: Double(index), y: 0.0))
        }
        let centerLine = LineChartDataSet(entries: centerLineData, label: "- 0% -")
            
        let lineChartDataSetSP500 = LineChartDataSet(entries: linearValuesSP500, label: "SP500")
        
        let lineChartDataSetDJI = LineChartDataSet(entries: linearValuesDJI, label: "DJI")
        
        let lineChartDataSetIXIC = LineChartDataSet(entries: linearValuesIXIC, label: "NASDAQ")
        
        let lineChartDataSetPortfolio = LineChartDataSet(entries: linearValuesPortfolio, label: "Portfolio")
        
        chartView.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.width(to: chartView)
        lineChartView.height(to: chartView)
        
        // Set the axis range before setting data
        setAxisRange()
            
        self.setData(centerLine: centerLine, lineChartSP500: lineChartDataSetSP500, lineChartDJI: lineChartDataSetDJI, lineChartIXIC: lineChartDataSetIXIC, lineChartPortfolio: lineChartDataSetPortfolio)
    }
    
    func setData(centerLine: LineChartDataSet, lineChartSP500: LineChartDataSet, lineChartDJI: LineChartDataSet, lineChartIXIC: LineChartDataSet, lineChartPortfolio: LineChartDataSet) {
        let set0 = centerLine
        set0.mode = .linear
        set0.drawCirclesEnabled = false
        set0.lineWidth = 1
        set0.lineDashLengths = [3, 3]
        set0.setColor(.label)
        set0.drawFilledEnabled = false
        set0.drawHorizontalHighlightIndicatorEnabled = true
        set0.drawVerticalHighlightIndicatorEnabled = false
        set0.highlightColor = .label
        
        let set1 = lineChartSP500
        set1.mode = .cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 1
        set1.setColor(.systemOrange)
        set1.drawFilledEnabled = false
        set1.drawHorizontalHighlightIndicatorEnabled = true
        set1.drawVerticalHighlightIndicatorEnabled = false
        set1.highlightColor = .label
        
        let set2 = lineChartDJI
        set2.mode = .cubicBezier
        set2.drawCirclesEnabled = false
        set2.lineWidth = 1
        set2.setColor(.systemBrown)
        set2.drawFilledEnabled = false
        set2.drawHorizontalHighlightIndicatorEnabled = true
        set2.drawVerticalHighlightIndicatorEnabled = false
        set2.highlightColor = .label

        let set3 = lineChartIXIC
        set3.mode = .cubicBezier
        set3.drawCirclesEnabled = false //draw circles in each spot
        set3.lineWidth = 1
        set3.setColor(.systemBlue)
        set3.drawFilledEnabled = false
        set3.drawVerticalHighlightIndicatorEnabled = true
        set3.drawHorizontalHighlightIndicatorEnabled = false
        set3.highlightColor = .label
        
        
        let set4 = lineChartPortfolio
        set4.mode = .linear// .horizontalBezier//.cubicBezier
        set4.drawCirclesEnabled = true
        set4.circleRadius = 3
//        set4.setCircleColor(NSUIColor.blue) //contorn color
        set4.circleHoleColor = .systemBackground//.yellow //center circle color
        set4.circleColors = [NSUIColor.red] //contorn color
        set4.lineWidth = 2
        set4.setColor(.label)
        set4.drawFilledEnabled = false
        set4.drawVerticalHighlightIndicatorEnabled = true
        set4.drawHorizontalHighlightIndicatorEnabled = false
        set4.highlightColor = .label
        
        let data = LineChartData(dataSets: [set0, set1, set2, set3, set4])
        data.setDrawValues(false)
        lineChartView.data = data
    }
}
