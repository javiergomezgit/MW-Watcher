//
//  ChartController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/2/22.
//

import UIKit
import Charts
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
    @IBOutlet weak var timeFrameSegmented: UISegmentedControl!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var cryptoImage: UIImageView!
    
    var selectedCandleChart = false
    
    var candleValues = [CandleChartDataEntry]()
    var linearValues = [ChartDataEntry]()
    var interval = "300"
    var intervalStock = "15min"
    var symbol = "bit"
    var timeIntervals = ["old" : "1:2", "mid" : "1:2", "now" : "1:2"]
    
    public var informationCryptoTicker = CryptosViewCellModel(symbol: "", name: "", price: "", change: "", changeMonth: "", volume: "", cryptoImage: UIImage())
    public var informationStockTicker = Tickers(ticker: "", marketPrice: 0.0, previousPrice: 0.0)
    //Tickers(ticker: "AA", marketPrice: 84.15, previousPrice: 86.1)

    @IBAction func timeFrameChange(_ sender: UISegmentedControl) {
        let index = timeFrameSegmented.selectedSegmentIndex
        
        if informationStockTicker.ticker == "" {
            switch index {
            case 0: self.interval = "300"
                break
            case 1: self.interval = "3600"
                break
            case 2: self.interval = "18000"
                break
            case 3: self.interval = "86400"
                break
            case 4: self.interval = "week"
                break
            case 5: self.interval = "month"
                break
            default:
                self.interval = "300"
            }
            loadCryptoPrices()
        } else {
            switch index {
            case 0: self.intervalStock = "15min"
                break
            case 1: self.intervalStock = "60min"
                break
            case 2: self.intervalStock = "18000"
                break
            case 3: self.intervalStock = "86400"
                break
            case 4: self.intervalStock = "week"
                break
            case 5: self.intervalStock = "month"
                break
            default:
                self.intervalStock = "15min"
            }
            selectedStockTicker()
        }
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //loadCryptoPrices()
        if informationStockTicker.ticker == "" {
            selectedCryptoTicker()
        } else {
            selectedStockTicker()
        }
    }
    
    private func selectedStockTicker() {
        let symbol = informationStockTicker.ticker
        let currentPrice = informationStockTicker.marketPrice
        let percentageChange = Float(informationStockTicker.previousPrice) //using previousPrice structure to store percentage change
        
        if percentageChange < 0.000 {
            currentPercentageLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            currentPercentageLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        self.symbol = symbol
        tickerLabel.text = symbol
        currentPriceLabel.text = String(currentPrice)
        currentPercentageLabel.text = "\(percentageChange)% Day"
        
        loadStockPrices()
    }
    
    private func loadStockPrices(){
        StocksAPI.shared.getStockValues(interval: self.intervalStock, symbol: symbol) { [weak self] result in
            switch result {
                
            case .success(let data):
                let data = data
                print (data)
                self?.stockData = data
                DispatchQueue.main.async {
                    self?.setUpStockModel()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                }
                print (error)
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
                
                self?.cryptoData = data
                print (data)
                DispatchQueue.main.async {
                    self?.setUpCryptoModel()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                }
                print (error)
            }
        }
    }
    
    private func setUpStockModel(){
        guard let modelCandles = stockData else { return }
        self.candleValues.removeAll()
        self.linearValues.removeAll()

        for (index, candleValue) in modelCandles.enumerated() {
            let startingAt = candleValue.start_timestamp
            guard let openPrice = Double(candleValue.open) else { return }
            guard let highPrice = Double(candleValue.high) else { return }
            guard let closePrice = Double(candleValue.close) else { return }
            guard let lowPrice = Double(candleValue.low) else { return }
            
            let candleValueEntry = CandleChartDataEntry(x: Double(index), shadowH: highPrice, shadowL: lowPrice, open: openPrice, close: closePrice)
            let linearValueEntry = ChartDataEntry(x: Double(index), y: closePrice)
            
            self.candleValues.append(candleValueEntry)
            self.linearValues.append(linearValueEntry)
            
            switch index {
            case 0:
                self.timeIntervals["old"] = startingAt
            case 29:
                self.timeIntervals["mid"] = startingAt
            case 59:
                self.timeIntervals["now"] = startingAt
            default: print ("")
            }
        }
        //setupDateLabel()
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
            
            self.candleValues.append(candleValueEntry)
            self.linearValues.append(linearValueEntry)
            
            switch index {
            case 0:
                self.timeIntervals["old"] = startingAt
            case 29:
                self.timeIntervals["mid"] = startingAt
            case 59:
                self.timeIntervals["now"] = startingAt
            default: print ("something")
            }
        }
        setupDateLabel()
        choseTypeChart()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        print(entry)
    }
    
    func setupDateLabel(){
        var dateFormat = "HH:mm"
        let index = timeFrameSegmented.selectedSegmentIndex
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
            let date = Date(timeIntervalSince1970: Double(time)!)
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(abbreviation: "PST") //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = dateFormat //"HH:mm"//"yyyy-MM-dd HH:mm" //Specify your format that you want
            let strDate = dateFormatter.string(from: date)
            if timeInterval.key == "old" {
                oldestTimeLabel.text = strDate
            } else if timeInterval.key == "mid" {
                middleTimeLabel.text = strDate
            } else {
                currentTimeLabel.text = strDate
            }
        }

        
//        let date = Date(timeIntervalSince1970: Double(mid!)!)
//        let dateFormatter = DateFormatter()
//        dateFormatter.timeZone = TimeZone(abbreviation: "PST") //Set timezone that you want
//        dateFormatter.locale = NSLocale.current
//        dateFormatter.dateFormat = "HH:mm"//"yyyy-MM-dd HH:mm" //Specify your format that you want
//        let strDateMid = dateFormatter.string(from: date)
                
//        let date = Date(timeIntervalSince1970: Double(now!)!)
//        let dateFormatter = DateFormatter()
//        dateFormatter.timeZone = TimeZone(abbreviation: "PST") //Set timezone that you want
//        dateFormatter.locale = NSLocale.current
//        dateFormatter.dateFormat = "HH:mm"//"yyyy-MM-dd HH:mm" //Specify your format that you want
//        let strDateNow = dateFormatter.string(from: date)
        
        
        
        
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
//        candleView.xAxis.labelPosition = .bottom
//        candleView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
//        candleView.xAxis.labelTextColor = .label
        candleView.xAxis.setLabelCount(3, force: true)

        return candleView
    }()
    
    func setDataCandleChart() {
        let set1 = CandleChartDataSet(entries: candleValues, label: "1 Hour Time Frame")
                
        set1.axisDependency = .left
        set1.setColor(UIColor(white: 80/255, alpha: 1))
       
        set1.drawHorizontalHighlightIndicatorEnabled = true
        set1.highlightColor = .systemRed
        set1.drawValuesEnabled = false
        set1.drawIconsEnabled = false
        set1.shadowColor = .label
        set1.shadowWidth = 1.1
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
        //lineChartView.animate(xAxisDuration: 0.2)
        
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
//        lineChartView.xAxis.labelPosition = .bottom
//        lineChartView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
//        lineChartView.xAxis.labelTextColor = .label
        lineChartView.xAxis.setLabelCount(3, force: true)
        
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
            set1.fill = Fill(color: UIColor(named: "uptrend")!)
            set1.fillAlpha = 0.1
        } else {
            set1.setColor(.red.withAlphaComponent(0.7))
            set1.fill = Fill(color: .red)
            set1.fillAlpha = 0.2
        }

        set1.drawFilledEnabled = true

        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightColor = .systemRed

        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        lineChartView.data = data
    }
}
