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
    @IBOutlet weak var chartWithTimes: UIView!
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var selectChartButton: UIButton!
    @IBOutlet weak var oldestTimeLabel: UILabel!
    @IBOutlet weak var middleTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var currentPriceLabel: UILabel!
    @IBOutlet weak var currentPercentageLabel: UILabel!
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var cryptoImage: UIImageView!
    @IBOutlet weak var pointingOpenLabel: UILabel!
    @IBOutlet weak var pointingLowLabel: UILabel!
    @IBOutlet weak var pointingDateLabel: UILabel!
    @IBOutlet weak var pointingCloseLabel: UILabel!
    @IBOutlet weak var pointingHighLabel: UILabel!
    @IBOutlet weak var pointingViewLabels: UIView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var segmentControl: HBSegmentedControl!
    
    var selectedCandleChart = false
    
    var candleValues = [CandleChartDataEntry]()
    var linearValues = [ChartDataEntry]()
    var interval = "300"
    var intervalStock = "15m&limit=35"
    var symbol = "bit"
    var timeIntervals = ["old" : "1:2", "mid" : "1:2", "now" : "1:2"]
    var times: [Int: String] = [:]
    var indexMarket = false
    var indexName = ""
    var currentPrice = 0.0
    
    public var informationCryptoTicker = CryptosViewCellModel(symbol: "", name: "", price: 0, change: 0, changeMonth: "", volume: "", cryptoImageName: "")
    public var informationStockTicker = TickersCurrentValues(ticker: "", marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
    public var nameTicker = ""
    
    public var imageCompany = UIImage(named: "mw-logo")

    ///Set by search, which opens the chart as soon as a result is tapped with only the ticker
    ///and name. The price and logo then load here alongside the history. Search used to fetch
    ///the price, then the logo, and only then open this screen, so the chart came three round
    ///trips after the tap. Every other entry point already passes a price and a logo.
    public var loadsQuoteAndLogo = false
    ///True until that price has come back; the header shows dashes rather than $0.0.
    private var awaitingQuote = false
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startStopSpinner(start: true)
        
        segmentControl.borderColor = .clear
        segmentControl.selectedLabelColor = UIColor.white
        segmentControl.unselectedLabelColor = UIColor(named: "colorAccent")!
        segmentControl.layer.cornerRadius = 10
        segmentControl.backgroundColor = .clear
        segmentControl.thumbColor = UIColor(named: "colorAccent")!
        let font = UIFont.systemFont(ofSize: 15) // pick the size you want
        segmentControl.font  = UIFont.boldSystemFont(ofSize: font.pointSize)
        segmentControl.selectedIndex = 0
        segmentControl.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)
        
        navigationItem.title = nameTicker
        
        if informationStockTicker.ticker == "" {
            segmentControl.items = ["15 min", "1 hr", "Day", "Week", "Month"]
            selectedCryptoTicker()
        } else {
            segmentControl.items = ["15 min", "1 hr", "Day", "Week"]
            self.intervalStock = "15m&limit=35"
            if loadsQuoteAndLogo {
                loadQuoteAndLogo()
            }
            selectedStockTicker()
        }
    }

        
    private let loadingView = ChartLoadingView()
    ///A skeleton chart over the chart area only, not the screen. A dimmed spinner used to
    ///cover everything, so the header - ticker, price, logo - and the timeframe buttons were
    ///hidden while the history loaded, and a chart opened from search looked no faster than
    ///when it waited on the search list.
    func startStopSpinner(start: Bool){
        if start {
            //A timeframe switch can start it while it is already up.
            guard loadingView.superview == nil else { return }
            loadingView.translatesAutoresizingMaskIntoConstraints = false
            chartView.addSubview(loadingView)
            NSLayoutConstraint.activate([
                loadingView.topAnchor.constraint(equalTo: chartView.topAnchor),
                loadingView.bottomAnchor.constraint(equalTo: chartView.bottomAnchor),
                loadingView.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
                loadingView.trailingAnchor.constraint(equalTo: chartView.trailingAnchor)
            ])
        } else {
            loadingView.removeFromSuperview()
        }
    }
    
    @objc func segmentValueChanged(_ sender: AnyObject?){
        
        let index = segmentControl.selectedIndex

        if informationStockTicker.ticker == "" {
            //Stocks decide for themselves in loadStockPrices: a cached timeframe shows no
            //loading state at all.
            startStopSpinner(start: true)
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
            case 0: self.intervalStock = "15m&limit=35"
                break
            case 1: self.intervalStock = "1h&limit=35"
                break
            case 2: self.intervalStock = "1d&limit=35"
                break
            case 3: self.intervalStock = "1wk&limit=35"
                break
            case 4: self.intervalStock = "1wk&limit=35"
                break
            default:
                self.intervalStock = "15m&limit=35"
            }
            selectedStockTicker()
        }
    }
    
    
    private func selectedStockTicker() {
        showStockHeader()
        loadStockPrices()
    }

    ///Fetched together, not one after the other, and neither waits for the history. Answers
    ///are matched to the ticker captured here, so a late one cannot land on another stock.
    private func loadQuoteAndLogo() {
        let ticker = informationStockTicker.ticker
        awaitingQuote = true

        StockAPI.shared.getPriceSingleTicker(ticker: ticker, timeRange: "&interval=1d&range=1d") { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                self.awaitingQuote = false
                switch result {
                case .success(let values):
                    //Keeps the ticker as searched, which the history and sharing are keyed by.
                    self.informationStockTicker = TickersCurrentValues(ticker: ticker,
                                                                       marketPrice: values.marketPrice,
                                                                       previousPrice: values.previousPrice,
                                                                       changePercent: values.changePercent)
                case .failure(let error):
                    //The chart is still worth showing; the header keeps its dashes.
                    print("Price for \(ticker) could not be loaded for the chart header: \(error)")
                }
                self.showStockHeader()
            }
        }

        //Decoration: the placeholder stays if there is no logo.
        StockAPI.shared.getLogoStock(ticker: ticker) { [weak self] result in
            guard case .success(let image) = result else { return }
            DispatchQueue.main.async {
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                self.imageCompany = image
                self.cryptoImage.image = image
            }
        }
    }

    private func showStockHeader() {
        let symbol = informationStockTicker.ticker
        self.currentPrice = informationStockTicker.marketPrice
        let currentPrice = informationStockTicker.marketPrice
        let percentageChange = informationStockTicker.changePercent
        let previousPrice = informationStockTicker.previousPrice

        if awaitingQuote || (loadsQuoteAndLogo && currentPrice == 0) {
            //Search opened this before the price was known, or it never came back.
            self.symbol = symbol
            tickerLabel.text = symbol
            cryptoImage.image = imageCompany
            for label in [currentPriceLabel, currentPercentageLabel, volumeLabel] {
                label?.text = "—"
                label?.textColor = .secondaryLabel
            }
            return
        }

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
        if indexMarket {
            tickerLabel.text = Self.displaySymbol(symbol)
            volumeLabel.text = ""
        } else {
            //The symbol alone. The header used to add " - <exchange>", but the chart
            //endpoint stopped sending an exchange name, so it only ever showed a dangling dash.
            tickerLabel.text = symbol
            volumeLabel.text = "$\(previousPrice)"
        }
        cryptoImage.image = imageCompany
        currentPriceLabel.text = String(currentPrice)
        currentPercentageLabel.text = "\(percentageChange)%"
    }

    ///Draws candles already seen straight away and only asks again when they are stale, so a
    ///timeframe switch back, or a stock reopened, does not wait on the network.
    ///
    ///The symbol and timeframe are captured before the request and checked when the answer
    ///lands. Answers used to be drawn in whatever order they arrived, so going 15 min -> 1 hr
    ///-> 15 min quickly could leave the 1 hr candles on screen under the 15 min button. A late
    ///answer is still cached, just not drawn.
    private func loadStockPrices(){
        let symbol = self.symbol
        let interval = intervalStock
        let isIndex = indexMarket

        let cached = ChartCache.shared.entry(symbol: symbol, interval: interval, isIndex: isIndex)
        if let cached {
            startStopSpinner(start: false)
            stockData = cached.values
            setUpStockModel()
            guard ChartCache.shared.isStale(cached, interval: interval, isIndex: isIndex) else { return }
        } else {
            startStopSpinner(start: true)
        }
        //With cached candles on screen a failed refresh is quiet: the chart is already there.
        let showsCachedChart = cached != nil

        let handle: (Result<[ValueStock], Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let data) = result, !data.isEmpty {
                    ChartCache.shared.store(data, symbol: symbol, interval: interval, isIndex: isIndex)
                }
                guard let self, self.symbol == symbol, self.intervalStock == interval else { return }

                switch result {
                case .success(let data) where !data.isEmpty:
                    self.startStopSpinner(start: false)
                    //A refresh that changed nothing is not redrawn, so the chart does not
                    //flicker or lose the point being touched.
                    if showsCachedChart, Self.sameCandles(data, cached?.values) { return }
                    self.stockData = data
                    self.setUpStockModel()
                case .success:
                    self.startStopSpinner(start: false)
                    print("Chart for \(symbol) \(interval) came back empty")
                    if !showsCachedChart {
                        ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self)
                    }
                case .failure(let error):
                    self.startStopSpinner(start: false)
                    print("Chart for \(symbol) \(interval) could not be loaded: \(error)")
                    if !showsCachedChart {
                        ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self)
                    }
                }
            }
        }

        if isIndex {
            ChartAPI.shared.getMarketValues(intervalTime: interval, symbol: symbol, completion: handle)
        } else {
            ChartAPI.shared.getStockValues(intervalTime: interval, symbol: symbol, completion: handle)
        }
    }

    ///Candles are in time order, so the count and the last candle tell whether a refresh
    ///brought anything new.
    private static func sameCandles(_ new: [ValueStock], _ old: [ValueStock]?) -> Bool {
        guard let old, old.count == new.count, let a = old.last, let b = new.last else { return false }
        return a.start_timestamp == b.start_timestamp && a.close == b.close
            && a.high == b.high && a.low == b.low && a.volume == b.volume
    }
    
    private func selectedCryptoTicker(){
        
        let symbol = informationCryptoTicker.symbol
        
        if informationCryptoTicker.change < 0 {
            currentPercentageLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            currentPercentageLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        tickerLabel.text = symbol
        self.currentPrice = informationCryptoTicker.price
        currentPriceLabel.text = String(informationCryptoTicker.price)
        currentPercentageLabel.text = "\(informationCryptoTicker.change)% Day"
//        nameLabel.text = informationCryptoTicker.name.uppercased()
        volumeLabel.text = "Vol.\(informationCryptoTicker.volume) MM"
        cryptoImage.image = UIImage(named: informationCryptoTicker.cryptoImageName)
        
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
        CryptoAPI.shared.getSelectedCrypto(interval: interval, symbol: symbol) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                
                DispatchQueue.main.async {
                    self.startStopSpinner(start: false)
                    if data.count != 0 {
                        self.cryptoData = data
                        self.setUpCryptoModel()
                    } else {
                        ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self)
                    }
                    
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self)
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
        resetChartState()
        
        for (index, candleValue) in modelCandles.enumerated() {
            candleValues.append(CandleChartDataEntry(x: Double(index),
                                                     shadowH: candleValue.high,
                                                     shadowL: candleValue.low,
                                                     open: candleValue.open,
                                                     close: candleValue.close))
            linearValues.append(ChartDataEntry(x: Double(index), y: candleValue.close))
            times[index] = String(candleValue.start_timestamp)
        }
        
        finishChartSetup()
    }
    
    private func setUpCryptoModel() {
        
        guard let modelCandles = cryptoData else { return }
        resetChartState()
        
        for candleValue in modelCandles {
            //Skip a malformed candle rather than abandoning the whole chart, which is what the
            //old `else { return }` did. Indexing off what has actually been appended keeps the
            //x positions contiguous despite the gaps.
            guard let openPrice = Double(candleValue.open),
                  let highPrice = Double(candleValue.max),
                  let closePrice = Double(candleValue.close),
                  let lowPrice = Double(candleValue.min) else { continue }
            
            let index = candleValues.count
            candleValues.append(CandleChartDataEntry(x: Double(index),
                                                     shadowH: highPrice,
                                                     shadowL: lowPrice,
                                                     open: openPrice,
                                                     close: closePrice))
            linearValues.append(ChartDataEntry(x: Double(index), y: closePrice))
            times[index] = candleValue.start_timestamp
        }
        
        finishChartSetup()
    }
    
    ///Clears everything rebuilt per load. `times` was previously left alone, so switching from
    ///a longer interval to a shorter one left stale keys behind and let an out-of-range index
    ///reach candleValues.
    private func resetChartState() {
        candleValues.removeAll()
        linearValues.removeAll()
        times.removeAll()
    }
    
    ///Anchors the three axis time labels and the OHLC readout to the data actually loaded.
    ///These were pinned to indices 0, 29 and 59, but the stock endpoint returns roughly 35
    ///candles: "now" was never set, so the right-hand axis label fell back to the current clock
    ///time, and printCLOH(entry: 59) silently did nothing, which is why the OHLC row kept
    ///showing its storyboard placeholders.
    private func finishChartSetup() {
        guard !candleValues.isEmpty else {
            choseTypeChart()
            return
        }
        
        let lastIndex = candleValues.count - 1
        if let oldest = times[0]            { timeIntervals["old"] = oldest }
        if let middle = times[lastIndex / 2] { timeIntervals["mid"] = middle }
        if let newest = times[lastIndex]    { timeIntervals["now"] = newest }
        
        printCLOH(entry: lastIndex)
        setupDateLabel()
        choseTypeChart()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        printCLOH(entry: Int(entry.x))
    }
    
    private func printCLOH(entry: Int) {
        //Any index can arrive here: the chart delegate passes back whatever the user touched,
        //and a stale times dictionary used to let an out-of-range index through to a crash.
        guard candleValues.indices.contains(entry),
              let stringTime = transformTime(entry: Double(entry)) else { return }
        
        let candle = candleValues[entry]
        
        pointingDateLabel.text = "Time: \(stringTime)"
        pointingOpenLabel.text = "O: $\(candle.open)"
        pointingLowLabel.text = "L: $\(candle.low)"
        pointingHighLabel.text = "H: $\(candle.high)"
        pointingCloseLabel.text = "C: $\(candle.close)"
        
        //Coloured by the move from the previous candle. The first candle has nothing to compare
        //against and used to leave both labels with no colour at all.
        var colorToShow = UIColor.label
        if entry > 0 {
            let previousClose = candleValues[entry - 1].close
            if previousClose > 0 {
                //Was ((previousClose * 100) / close) - 100, which measured the move backwards
                let changePercentage = ((candle.close * 100) / previousClose) - 100
                colorToShow = changePercentage < 0
                    ? (UIColor(named: "downtrend") ?? .label)
                    : (UIColor(named: "uptrend") ?? .label)
            }
        }
        pointingOpenLabel.textColor = colorToShow
        pointingCloseLabel.textColor = colorToShow
    }
    
    ///Index symbols carry Yahoo's "^" prefix, which the API needs and people should not see:
    ///the index chart's header and its share text both read "^DJI". Strip it wherever a symbol
    ///is shown and keep it wherever one is requested - self.symbol still holds the raw value.
    private static func displaySymbol(_ symbol: String) -> String {
        symbol.hasPrefix("^") ? String(symbol.dropFirst()) : symbol
    }
    
    ///What the share text says, worked out from what the chart was opened with.
    ///
    ///The old version picked its branch by whether nameTicker was set, and every entry point
    ///sets it, so it always took the stock branch. Crypto charts keep their numbers in
    ///informationCryptoTicker and leave informationStockTicker empty, so a shared crypto chart
    ///said a blank symbol, $0.00 and 0.00%. The index and crypto branches were never reached.
    ///An empty stock ticker is the test viewDidLoad already uses to choose the crypto path.
    private static func shareFields(stock: TickersCurrentValues,
                                    crypto: CryptosViewCellModel,
                                    nameTicker: String,
                                    indexName: String) -> (name: String, symbol: String, price: String, change: String) {
        let isCrypto = stock.ticker.isEmpty
        let name = isCrypto ? crypto.name : (nameTicker.isEmpty ? indexName : nameTicker)
        let symbol = isCrypto ? crypto.symbol : displaySymbol(stock.ticker)
        let price = isCrypto ? crypto.price : stock.marketPrice
        let change = isCrypto ? crypto.change : stock.changePercent
        let trend = change >= 0 ? "📈 " : "📉 "
        return (name, symbol, String(format: "%.2f", price), trend + String(format: "%.2f", change))
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        
        let fields = Self.shareFields(stock: informationStockTicker,
                                      crypto: informationCryptoTicker,
                                      nameTicker: nameTicker,
                                      indexName: indexName)
        let defaultImage = UIImage(named: "mw-logo") ?? UIImage()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd 'at' h:mm a"
        let currentDate = formatter.string(from: Date())
                
//        let appURLString = "https://apps.apple.com/us/app/market-news-and-charts/id1568502942" // Replace with your App Store ID
//        let appURL = URL(string: appURLString) ?? URL(string: "https://bullis-square.com")!
        
        let formattedText = """
        🏪 \(fields.symbol) - \(fields.name)
        Price: $\(fields.price)
        Changed:\(fields.change)%

        📅 Today: \(currentDate)
        Shared via Bullish Square 📱 
        """
        
        // Capture and resize chart image (replace `chartView` with your actual chart view)
        let chartImage = chartWithTimes.asImage()?.resized(to: CGSize(width: 300, height: 300)) ?? defaultImage
                    
        let activityItems: [Any] = [formattedText, chartImage]
        
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        present(activityVC, animated: true)
        
    }
    
    func transformTime(entry: Double) -> String? {
        let timeString = self.times[Int(entry)]
        var strDate: String?
        if timeString != nil {
            
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
            
            strDate = Support.sharedSupport.convertTimeStampToDate(timeString: timeString!, dateFormat: dateFormat)

        } else {
            strDate = nil
        }

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
    
    ///Runs on every load and timeframe switch, not only on the line/candle button. It used to
    ///re-add the visible chart and its four constraints each time; that view was already in
    ///place, so another identical set piled up per load. Each chart is now added and
    ///constrained once, and switching only shows one and hides the other.
    func choseTypeChart(){
        installOnce(candleView)
        installOnce(lineChartView)
        candleView.isHidden = !selectedCandleChart
        lineChartView.isHidden = selectedCandleChart

        if selectedCandleChart {
            selectChartButton.setImage(UIImage(named: "chart.line.uptrend.xyaxis"), for: .normal)
            setDataCandleChart()
        } else {
            selectChartButton.setImage(UIImage(named: "chart.bar.fill"), for: .normal)
            setDataLineChart()
        }
    }

    ///Under the loading skeleton when it is up, so a chart drawn from cache mid-load cannot
    ///cover it.
    private func installOnce(_ chart: UIView) {
        guard chart.superview == nil else { return }
        if loadingView.superview === chartView {
            chartView.insertSubview(chart, belowSubview: loadingView)
        } else {
            chartView.addSubview(chart)
        }
        chart.centerInSuperview()
        chart.width(to: chartView)
        chart.height(to: chartView)
    }
    
    //MARK: Candle Chart
    lazy var candleView: CandleStickChartView = {
        let candleView = CandleStickChartView()
        candleView.delegate = self
        candleView.leftAxis.enabled = false
        candleView.rightAxis.enabled = true
        candleView.animate(xAxisDuration: 0.5)
        
        candleView.dragEnabled = true
        candleView.setScaleEnabled(true)
        candleView.maxVisibleCount = 60
        candleView.pinchZoomEnabled = true
        candleView.doubleTapToZoomEnabled = false
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
        set1.drawValuesEnabled = false
        set1.drawIconsEnabled = true
        set1.shadowColor = .label
        set1.shadowWidth = 1.0
        set1.decreasingColor = UIColor(named: "downtrend")!
        set1.decreasingFilled = true
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
        lineChartView.doubleTapToZoomEnabled = false
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
        //The type toggle stays tappable after a failed load, and first!/last! below used to
        //trap on an empty set.
        guard let v1 = linearValues.first?.y, let v2 = linearValues.last?.y else {
            lineChartView.data = nil
            return
        }
        
        let set1 = LineChartDataSet(entries: linearValues, label: "Price")
        set1.mode = .cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 1

        // Gradient helper
        func makeGradient(colors: [UIColor], angle: CGFloat = 90.0) -> Fill {
            let cgColors = colors.map { $0.cgColor } as CFArray
            let locations: [CGFloat] = [0.0, 0.4]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: cgColors,
                                      locations: locations)!

            // ✅ Use LinearGradientFill instead of Fill.fillWithLinearGradient
            return LinearGradientFill(gradient: gradient, angle: angle)
        }

        if v1 < v2 {
            let gradientFill = makeGradient(colors: [UIColor(named: "uptrend")!.withAlphaComponent(0.1), UIColor(named: "uptrend")!.withAlphaComponent(0.5)])
            set1.fill = gradientFill
            set1.setColor(UIColor(named: "uptrend")!)
        } else {
            let gradientFill = makeGradient(colors: [UIColor(named: "downtrend")!.withAlphaComponent(0.5), UIColor(named: "downtrend")!.withAlphaComponent(0.1)])
            set1.fill = gradientFill
            set1.setColor(UIColor(named: "downtrend")!)
        }


        set1.fillAlpha = 1.0
        set1.drawFilledEnabled = true

        // Highlight / indicator styles
        set1.drawVerticalHighlightIndicatorEnabled = true
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightLineWidth = 1
        set1.highlightColor = .systemBlue
        set1.drawValuesEnabled = false
        set1.drawIconsEnabled = false

        let data = LineChartData(dataSet: set1)
        lineChartView.data = data
    }
    
    @IBAction func openNewsButton(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController else { return }

        if self.informationCryptoTicker.name == "" {
            let ticker = informationStockTicker.ticker
            
            if indexMarket {
                destination.ticker = indexName
                destination.name = indexName
            } else {
                destination.ticker = ticker
                destination.name = nameTicker
            }
        } else {
            destination.ticker = informationCryptoTicker.symbol
            destination.cryptoCoin = true
            destination.name = informationCryptoTicker.name
        }
        
        destination.modalTransitionStyle = .crossDissolve

        let navController = UINavigationController(rootViewController: destination)
        navController.modalPresentationStyle = .pageSheet
        navController.modalTransitionStyle = .crossDissolve
        self.present(navController, animated: true)
    }
}

extension UIView {
    func asImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
