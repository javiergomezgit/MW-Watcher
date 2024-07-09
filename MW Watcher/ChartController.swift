//
//  ChartController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/2/22.
//

import UIKit
import DGCharts
import TinyConstraints

class ChartController: UIViewController, ChartViewDelegate {
    
    private var cryptoData: [QuoteInvidual]?
    private var stockData: [ValueStock]?
    @IBOutlet weak var chartView: UIView!
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var selectChartButton: UIButton!
    @IBOutlet weak var oldestTimeLabel: UILabel!
    @IBOutlet weak var middleTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var currentPriceLabel: UILabel!
    @IBOutlet weak var currentPercentageLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var cryptoImage: UIImageView!
    @IBOutlet weak var pointingOpenLabel: UILabel!
    @IBOutlet weak var pointingLowLabel: UILabel!
    @IBOutlet weak var pointingDateLabel: UILabel!
    @IBOutlet weak var pointingCloseLabel: UILabel!
    @IBOutlet weak var pointingHighLabel: UILabel!
    @IBOutlet weak var pointingChangeLabel: UILabel!
    @IBOutlet weak var pointingViewLabels: UIView!
    
    @IBOutlet weak var segmentControl: HBSegmentedControl!
    
    var selectedCandleChart = false
    
    var CLOHValues = [MarketsCandles]()
    var candleValues = [CandleChartDataEntry]()
    var linearValues = [ChartDataEntry]()
    var interval = "300"
    var intervalStock = "15min"
    var symbol = "bit"
    var timeIntervals = ["old" : "1:2", "mid" : "1:2", "now" : "1:2"]
    var times = [0 : ""]
    var indexMarket = false
    var indexName = ""
    var currentPrice = 0.0
    
    public var informationCryptoTicker = CryptosViewCellModel(symbol: "", name: "", price: "", change: "", changeMonth: "", volume: "", cryptoImage: UIImage())
    
    public var informationStockTicker = TickersCurrentValues(ticker: "", marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
    public var nameTicker = ""
    
    public var imageCompany = UIImage(named: "mw-logo")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pointingChangeLabel.text = ""
        startStopSpinner(start: true)
        
        segmentControl.borderColor = .clear
        segmentControl.selectedLabelColor = .white
        segmentControl.unselectedLabelColor = .darkGray
        segmentControl.backgroundColor = .lightGray
        segmentControl.thumbColor = .black
        segmentControl.selectedIndex = 0
        segmentControl.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)
        
        if informationStockTicker.ticker == "" {
            segmentControl.items = ["15 min", "1 hr", "Day", "Week", "Month"]
            selectedCryptoTicker()
        } else {
            segmentControl.items = ["15 min", "1 hr", "Day", "Week"]
            self.intervalStock = "15m"
            selectedStockTicker()
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
    
    @objc func segmentValueChanged(_ sender: AnyObject?){
        
        let index = segmentControl.selectedIndex
        
        startStopSpinner(start: true)
        
        if informationStockTicker.ticker == "" {
            switch index {
            case 0: self.interval = "900"
                break
            case 1: self.interval = "3600"
                break
            case 2: self.interval = "18000"
                break
            case 3: self.interval = "week"
                break
            case 4: self.interval = "month"
                break
            default:
                self.interval = "300"
            }
            loadCryptoPrices()
        } else {
            switch index {
            case 0: self.intervalStock = "15m"
                break
            case 1: self.intervalStock = "1h"
                break
            case 2: self.intervalStock = "1d"
                break
            case 3: self.intervalStock = "1wk"
                break
            case 4: self.intervalStock = "1wk"
                break
            default:
                self.intervalStock = "15m"
            }
            selectedStockTicker()
        }
    }
    
    
    private func selectedStockTicker() {
        let symbol = informationStockTicker.ticker
        self.currentPrice = informationStockTicker.marketPrice
        let currentPrice = informationStockTicker.marketPrice
        let percentageChange = informationStockTicker.changePercent
        let previousPrice = informationStockTicker.previousPrice
        let nameCompany = nameTicker
        
        if percentageChange < 0.0 {
            currentPercentageLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            volumeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            currentPercentageLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            volumeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        self.symbol = symbol
        tickerLabel.text = symbol
        if indexMarket {
            nameLabel.text = indexName
            volumeLabel.text = ""
        } else {
            nameLabel.text = nameCompany
            volumeLabel.text = "$\(previousPrice)"
        }
        cryptoImage.image = imageCompany
        currentPriceLabel.text = String(currentPrice)
        currentPercentageLabel.text = "\(percentageChange)%"
        
        loadStockPrices()
    }
    
    private func loadStockPrices(){
        if indexMarket {
            ChartsAPI.shared.getMarketValues(intervalTime: self.intervalStock, symbol: symbol) { [weak self] result in
                switch result {
                    
                case .success(let data):
                    if data.count != 0  {
                        self?.stockData = data
                        DispatchQueue.main.async {
                            self?.startStopSpinner(start: false)
                            self?.setUpStockModel()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.startStopSpinner(start: false)
                            ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self!)
                        }
                        print ("no more API")
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                    }
                    print (error)
                }
            }
        } else {
            ChartsAPI.shared.getStockValues(intervalTime: self.intervalStock, symbol: symbol) { [weak self] result in
                switch result {
                    
                case .success(let data):
                    if data.count != 0  {
                        self?.stockData = data
                        DispatchQueue.main.async {
                            self?.startStopSpinner(start: false)
                            self?.setUpStockModel()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.startStopSpinner(start: false)
                            ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self!)
                        }
                        print ("no more API")
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                    }
                    print (error)
                }
            }
        }
        
    }
    
    private func selectedCryptoTicker(){
        
        let symbol = informationCryptoTicker.symbol
        
        if Float(informationCryptoTicker.change)! < 0.000 {
            currentPercentageLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            currentPercentageLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        tickerLabel.text = symbol
        var currentPrice = informationCryptoTicker.price
        currentPrice = currentPrice.replacingOccurrences(of: "$", with: "")
        currentPrice = currentPrice.replacingOccurrences(of: ",", with: "")
        
        self.currentPrice = Double(currentPrice) ?? 0.0
        currentPriceLabel.text = informationCryptoTicker.price
        currentPercentageLabel.text = "\(informationCryptoTicker.change)% Day"
        nameLabel.text = informationCryptoTicker.name.uppercased()
        volumeLabel.text = "Vol.\(informationCryptoTicker.volume) MM"
        cryptoImage.image = informationCryptoTicker.cryptoImage
        
        //Will use pair ID instead of symbol/ticker
        switch symbol {
        case "BTC":
            self.symbol = "945629"
        case "ETH":
            self.symbol = "1058142" //Binance
        case "LTC":
            self.symbol = "1056828" //Binance
        case "DOGE":
            self.symbol = "1158819" //Binance
        case "ADA":
            self.symbol = "1055297" //Synthetic
        case "DOT":
            self.symbol = "1165465" //Cryptopia
        case "BCH":
            self.symbol = "1099022" //Binance
        case "XLM":
            self.symbol = "1093968" //Synthetic
        case "BNB":
            self.symbol = "1054919" //Binance
        case "XMR":
            self.symbol = "1176959" //Binance
        case "XRP":
            self.symbol = "1057392" //Index Investing.com
        case "USDT":
            self.symbol = "1031397" //Kraken
        case "LINK":
            self.symbol = "1070588" //Synthetic
        case "USDC":
            self.symbol = "1142432" //Binance
        default:
            print ("Ticker not found")
        }
        loadCryptoPrices()
    }
    
    private func loadCryptoPrices() {
        CryptosAPI.shared.getSelectedCrypto(interval: interval, symbol: symbol) { [weak self] result in
            switch result {
            case .success(let data):
                
                DispatchQueue.main.async {
                    self?.startStopSpinner(start: false)
                    if data.count != 0 {
                        self?.cryptoData = data
                        self?.setUpCryptoModel()
                    } else {
                        ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self!)
                    }
                    
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                }
                print (error)
            }
        }
    }
    
    static let volumeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        formatter.groupingSeparator = ","
        return formatter
    }()
    
    private func setUpStockModel(){
        guard let modelCandles = stockData else { return }
        self.candleValues.removeAll()
        self.linearValues.removeAll()
        
//        var volumeReduce = NSNumber()
        for (index, candleValue) in modelCandles.enumerated() {
            let startingAt = candleValue.start_timestamp
            let openPrice = candleValue.open
            let highPrice = candleValue.high
            let closePrice = candleValue.close
            let lowPrice = candleValue.low
//            let volume = candleValue.volume
            
            let candleValueEntry = CandleChartDataEntry(x: Double(index), shadowH: highPrice, shadowL: lowPrice, open: openPrice, close: closePrice)
            let linearValueEntry = ChartDataEntry(x: Double(index), y: closePrice)
            let CLOHValue = MarketsCandles(start_timestamp: startingAt, open: openPrice, high: highPrice, low: lowPrice, close: closePrice)
            
//            volumeReduce = NSNumber(value: (volume/1000))
            
            
            self.candleValues.append(candleValueEntry)
            self.linearValues.append(linearValueEntry)
            self.CLOHValues.append(CLOHValue)
            
            switch index {
            case 0:
                self.timeIntervals["old"] = String(startingAt)
            case 29:
                self.timeIntervals["mid"] = String(startingAt)
            case 59:
                self.timeIntervals["now"] = String(startingAt)
            default: print ("")
            }
            
            times[index] = String(startingAt)
        }
        
//        if !indexMarket {
//            if let volumeRound = ChartController.volumeFormatter.string(from: volumeReduce) {
//                //self.volumeLabel.text = "Vol. \(volumeRound) MM" //22866
//            }
//        } else {
//            //self.volumeLabel.text = ""
//        }
        
        printCLOH(entry: 59)
        setupDateLabel()
        choseTypeChart()
    }
    
    private func setUpCryptoModel() {
        
        guard let modelCandles = cryptoData else { return }
        self.candleValues.removeAll()
        self.linearValues.removeAll()
        
        for (index, candleValue) in modelCandles.enumerated() {
            let startingAt = candleValue.start_timestamp
            guard let openPrice = Double(candleValue.open) else { return }
            guard let highPrice = Double(candleValue.max) else { return }
            guard let closePrice = Double(candleValue.close) else { return }
            guard let lowPrice = Double(candleValue.min) else { return }
            
            let candleValueEntry = CandleChartDataEntry(x: Double(index), shadowH: highPrice, shadowL: lowPrice, open: openPrice, close: closePrice)
            let linearValueEntry = ChartDataEntry(x: Double(index), y: closePrice)
            let CLOHValue = MarketsCandles(start_timestamp: Double(startingAt)!, open: openPrice, high: highPrice, low: lowPrice, close: closePrice)

            self.candleValues.append(candleValueEntry)
            self.linearValues.append(linearValueEntry)
            self.CLOHValues.append(CLOHValue)
            
            switch index {
            case 0:
                self.timeIntervals["old"] = startingAt
            case 29:
                self.timeIntervals["mid"] = startingAt
            case 59:
                self.timeIntervals["now"] = startingAt
            default: print ("something")
            }
            times[index] = String(startingAt)
        }
        
        printCLOH(entry: 59)
        setupDateLabel()
        choseTypeChart()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
//        print(entry)
//        let timeIndex = entry.x
//        let stringTime = transformTime(entry: timeIndex)
//        let open = candleValues[Int(entry.x)].open
//        let low = candleValues[Int(entry.x)].low
//        let close = candleValues[Int(entry.x)].close //same as current price for the current candle
//        let high = candleValues[Int(entry.x)].high
//
//        pointingDateLabel.text = "Date/Time: \(stringTime)"
//        pointingOpenLabel.text = "Open: $\(open)"
//        pointingLowLabel.text = "Low: $\(low)"
//        pointingHighLabel.text = "High: $\(high)"
//        pointingCloseLabel.text = "Close: $\(close)"
//
//        pointingChangeLabel.text = "Change: N/A"
//        if Int(entry.x) > 0 {
//            let previousClose = candleValues[Int(entry.x)-1].close
//            let changePercentage = ((previousClose * 100) / close) - 100
//
//            let rounded = Double(round(100*changePercentage)/100)
//            if rounded < 0  {
//                pointingChangeLabel.textColor = UIColor(named: "downtrend")!
//            } else {
//                pointingChangeLabel.textColor = UIColor(named: "uptrend")!
//            }
//            pointingChangeLabel.text = "Change: \(rounded)%"
//        }
        printCLOH(entry: Int(entry.x))
    }
    
    private func printCLOH(entry: Int) {
        let timeIndex = entry
        let stringTime = transformTime(entry: Double(timeIndex))
        let open = candleValues[Int(entry)].open
        let low = candleValues[Int(entry)].low
        let close = candleValues[Int(entry)].close //same as current price for the current candle
        let high = candleValues[Int(entry)].high

        pointingDateLabel.text = "Date/Time: \(stringTime)"
        pointingOpenLabel.text = "Open: $\(open)"
        pointingLowLabel.text = "Low: $\(low)"
        pointingHighLabel.text = "High: $\(high)"
        pointingCloseLabel.text = "Close: $\(close)"
        
        pointingChangeLabel.text = "Change: N/A"
        if Int(entry) > 0 {
            let previousClose = candleValues[Int(entry)-1].close
            let changePercentage = ((previousClose * 100) / close) - 100
            
            let rounded = Double(round(100*changePercentage)/100)
            if rounded < 0  {
                pointingChangeLabel.textColor = UIColor(named: "downtrend")!
            } else {
                pointingChangeLabel.textColor = UIColor(named: "uptrend")!
            }
            pointingChangeLabel.text = "Change: \(rounded)%"
        }
    }

    
    func transformTime(entry: Double) -> String {
        var dateFormat = "HH:mm"
        let index = segmentControl.selectedIndex //timeFrameSegmented.selectedSegmentIndex
        switch index {
        case 0:
            dateFormat = "HH:mm"
            break
        case 1:
            dateFormat = "HH:mm"
            break
        case 2:
            dateFormat =  "MM/dd"
            break
        case 3:
            dateFormat =  "yyyy/MM/dd"
            break
        case 4:
            dateFormat =  "yyyy/MM/dd"
            break
        case 5:
            dateFormat =  "yyyy/MM"
            break
        default:
            dateFormat =  "yyyy-MM-dd HH:mm"
        }
        
        let timeString = self.times[Int(entry)]!
        let strDate = Support.sharedSupport.convertTimeStampToDate(timeString: timeString, dateFormat: dateFormat)

        return strDate
    }
    
    
    
    func setupDateLabel(){
        var dateFormat = "HH:mm"
        let index = segmentControl.selectedIndex //timeFrameSegmented.selectedSegmentIndex
        switch index {
        case 0:
            dateFormat = "HH:mm"
            break
        case 1:
            dateFormat = "HH:mm"
            break
        case 2:
            dateFormat =  "MM/dd"
            break
        case 3:
            dateFormat =  "yyyy/MM/dd"
            break
        case 4:
            dateFormat =  "yyyy/MM/dd"
            break
        case 5:
            dateFormat =  "yyyy/MM"
            break
        default:
            dateFormat =  "yyyy-MM-dd HH:mm"
        }
        
        for timeInterval in timeIntervals {
            let time = timeInterval.value
            let strDate = Support.sharedSupport.convertTimeStampToDate(timeString: time, dateFormat: dateFormat)
            
            if timeInterval.key == "old" {
                oldestTimeLabel.text = strDate
            } else if timeInterval.key == "mid" {
                middleTimeLabel.text = strDate
            } else {
                currentTimeLabel.text = strDate
            }
        }
    }
    
    @IBAction func selectTypeChart(_ sender: UIButton) {
        if selectedCandleChart {
            selectedCandleChart = false
        } else {
            selectedCandleChart = true
        }
        choseTypeChart()
    }
    
    func choseTypeChart(){
        if selectedCandleChart {
            lineChartView.removeFromSuperview()
            chartView.addSubview(candleView)
            candleView.centerInSuperview()
            candleView.width(to: chartView)
            candleView.height(to: chartView)
            
            selectChartButton.setImage(UIImage(named: "candles"), for: .normal)
            setDataCandleChart()
        } else {
            candleView.removeFromSuperview()
            chartView.addSubview(lineChartView)
            lineChartView.centerInSuperview()
            lineChartView.width(to: chartView)
            lineChartView.height(to: chartView)
            
            selectChartButton.setImage(UIImage(named: "chartline"), for: .normal)
            setDataLineChart()
        }
    }
    
    //MARK: Candle Chart
    lazy var candleView: CandleStickChartView = {
        let candleView = CandleStickChartView()
        candleView.delegate = self
        
        candleView.leftAxis.enabled = false
        candleView.rightAxis.enabled = true
        //candleView.animate(xAxisDuration: 3.5)
        
        candleView.dragEnabled = false
        candleView.setScaleEnabled(true)
        candleView.maxVisibleCount = 60
        candleView.pinchZoomEnabled = false
        candleView.doubleTapToZoomEnabled = true
        candleView.dragXEnabled = true
        candleView.autoScaleMinMaxEnabled = true
        candleView.legend.enabled = false
        
        candleView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        candleView.rightAxis.labelTextColor = .label
        candleView.rightAxis.spaceTop = 0.3
        candleView.rightAxis.spaceBottom = 0.3
        candleView.rightAxis.setLabelCount(8, force: true)
        candleView.rightAxis.axisLineColor = .label
        candleView.rightAxis.labelPosition = .outsideChart
        
        candleView.xAxis.enabled = true
        candleView.xAxis.labelPosition = .top
        candleView.xAxis.yOffset = 10
        candleView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        candleView.xAxis.labelTextColor = .label
        candleView.xAxis.setLabelCount(5, force: true)
        
        return candleView
    }()
    
    func setDataCandleChart() {
        let set1 = CandleChartDataSet(entries: candleValues, label: "1 Hour Time Frame")
        
        set1.axisDependency = .left
        set1.setColor(UIColor(white: 80/255, alpha: 1))
//        set1.setDrawHighlightIndicators(true)
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.drawVerticalHighlightIndicatorEnabled = true
        set1.highlightLineWidth = 1
        set1.highlightColor = .systemBlue
        set1.drawValuesEnabled = true
        set1.drawIconsEnabled = true
        set1.shadowColor = .label
        set1.shadowWidth = 1.0
        set1.decreasingColor = UIColor(named: "downtrend")!
        set1.decreasingFilled = false
        set1.increasingColor = UIColor(named: "uptrend")
        set1.increasingFilled = true
        
        let data = CandleChartData(dataSet: set1)
        candleView.data = data
    }
    
    
    //MARK: Linear Chart
    lazy var lineChartView: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        lineChartView.animate(xAxisDuration: 0.2)
        
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.maxVisibleCount = 60
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
        lineChartView.xAxis.setLabelCount(5, force: true)
        
        return lineChartView
    }()
    
    func setDataLineChart() {
        let set1 = LineChartDataSet(entries: linearValues, label: "Subscribs")
        
        set1.mode = .cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 3
        let v1 = linearValues.first!.y
        let v2 = linearValues.last!.y
        if v1 < v2 {
            set1.setColor(UIColor(named: "uptrend")!)
            set1.fill = ColorFill(color: UIColor(named: "uptrend")!)
//            set1.fill = Fill(color: UIColor(named: "uptrend")!)
            set1.fillAlpha = 0.1
        } else {
            set1.setColor(.red.withAlphaComponent(0.7))
            set1.fill = ColorFill(color: .red)
            set1.fillAlpha = 0.2
        }
        
        set1.drawFilledEnabled = true
//        set1.setDrawHighlightIndicators(true)
        set1.drawVerticalHighlightIndicatorEnabled = true
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightLineWidth = 1
        set1.highlightColor = .systemBlue
        set1.drawValuesEnabled = true
        set1.drawIconsEnabled = true
        
        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        lineChartView.data = data
    }
    
    @IBAction func openNewsButton(_ sender: UIButton) {
        if self.informationCryptoTicker.name == "" {
            let ticker = informationStockTicker.ticker
            
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController
            
            if indexMarket {
                destination!.ticker = indexName
                destination!.name = indexName
            } else {
                destination!.ticker = ticker
                destination!.name = nameTicker
            }
                        
            destination!.modalTransitionStyle = .crossDissolve
            self.present(destination!, animated: true, completion: nil)
            //        self.show(destination!, sender: self)
        } else {
            //sender.isEnabled = false
            let ticker = informationCryptoTicker.symbol
            
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController
            
            destination!.ticker = ticker
            destination!.cryptoCoin = true
            destination!.name = informationCryptoTicker.name
           
            destination!.modalTransitionStyle = .crossDissolve
            self.present(destination!, animated: true, completion: nil)
        }
    }
}
