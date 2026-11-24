//
//  ChartController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/2/22.
//

import SwiftUI
import TinyConstraints
import UIKit

class ChartController: UIViewController {
    
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
    
    ///Candles by default: they show the open, high and low a line hides.
    var selectedCandleChart = true
    
    ///A coin's candle size on the crypto chart: 900, 3600, 18000, week or month.
    var interval = "300"
    ///A stock or index chart's time span, one of `ChartAPI.spans` (BS-327).
    var span = "1D"
    var symbol = "bit"
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

    ///What the Swift Charts chart draws (BS-327). It replaced the DGCharts line and candle views.
    private let chartModel = PriceChartModel()
    ///The header as it was when a finger went down on the chart, put back when it lifts.
    private var headerBeforeScrub: (price: String?, priceColor: UIColor, change: String?, changeColor: UIColor)?
    private let scrubFeedback = UISelectionFeedbackGenerator()
        
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
        installChart()
        
        if informationStockTicker.ticker == "" {
            segmentControl.items = ["15 min", "1 hr", "Day", "Week", "Month"]
            selectedCryptoTicker()
        } else {
            segmentControl.items = ChartAPI.spans
            if loadsQuoteAndLogo {
                loadQuoteAndLogo()
            }
            selectedStockTicker()
            loadCompanyNameIfNeeded()
        }
        addActionRow()
    }

    ///A chart opened from a $TICKER in a post knows only the symbol. The name comes from the
    ///watchlist when the stock is in it, else from search (shared on the server for hours).
    ///Decoration: without it the header shows the symbol.
    private func loadCompanyNameIfNeeded() {
        let ticker = informationStockTicker.ticker
        guard !indexMarket, !ticker.isEmpty,
              nameTicker.isEmpty || nameTicker.uppercased() == ticker.uppercased() else { return }
        if let saved = SaveTickers().loadTickers().first(where: { $0.ticker == ticker }),
           !saved.nameTicker.isEmpty, saved.nameTicker.uppercased() != ticker.uppercased() {
            nameTicker = saved.nameTicker
            return setHeaderTitle(symbol: ticker)
        }
        StockAPI.shared.searchStocks(ticker: ticker) { [weak self] result in
            guard case .success(let matches) = result,
                  let match = matches.first(where: { $0.ticker.uppercased() == ticker.uppercased() }),
                  !match.nameTicker.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                self.nameTicker = match.nameTicker
                self.setHeaderTitle(symbol: ticker)
            }
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
            guard ChartAPI.spans.indices.contains(index) else { return }
            span = ChartAPI.spans[index]
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

    ///The symbol once, Apple Stocks style: small in the bar, with the company's name by the
    ///logo. Without a name (a chart opened from a $TICKER in a post knows only the symbol),
    ///the symbol goes by the logo and the bar stays empty; it used to say AAPL in both.
    private func setHeaderTitle(symbol: String, name: String? = nil) {
        let name = (name ?? nameTicker).trimmingCharacters(in: .whitespaces)
        let hasName = !name.isEmpty && name.uppercased() != symbol.uppercased()
            && name.uppercased() != Self.displaySymbol(symbol).uppercased()
        navigationItem.title = hasName ? symbol : nil
        tickerLabel.text = hasName ? name : symbol
        tickerLabel.adjustsFontSizeToFitWidth = true
        tickerLabel.minimumScaleFactor = 0.6
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
            setHeaderTitle(symbol: symbol)
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
            setHeaderTitle(symbol: Self.displaySymbol(symbol))
            volumeLabel.text = ""
        } else {
            //The symbol alone. The header used to add " - <exchange>", but the chart
            //endpoint stopped sending an exchange name, so it only ever showed a dangling dash.
            setHeaderTitle(symbol: symbol)
            volumeLabel.text = priceText(previousPrice)
        }
        cryptoImage.image = imageCompany
        //Formatted like the scrubbed price, which used to be the only formatted one: the
        //header first showed raw doubles such as 271.4900016.
        currentPriceLabel.text = priceText(currentPrice)
        currentPercentageLabel.text = Self.changeText(percentageChange)
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
        let span = self.span
        let isIndex = indexMarket

        let cached = ChartCache.shared.entry(symbol: symbol, span: span, isIndex: isIndex)
        if let cached {
            startStopSpinner(start: false)
            stockData = cached.values
            setUpStockModel()
            guard ChartCache.shared.isStale(cached, span: span) else { return }
        } else {
            startStopSpinner(start: true)
        }
        //With cached candles on screen a failed refresh is quiet: the chart is already there.
        let showsCachedChart = cached != nil

        let handle: (Result<[ValueStock], Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let data) = result, !data.isEmpty {
                    ChartCache.shared.store(data, symbol: symbol, span: span, isIndex: isIndex)
                }
                guard let self, self.symbol == symbol, self.span == span else { return }

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
                    print("Chart for \(symbol) \(span) came back empty")
                    if !showsCachedChart {
                        ShowAlerts.showSimpleAlert(title: "Limit - Free version!", message: "You exceded the amount of requests, wait 1 minute.", titleButton: "OK", over: self)
                    }
                case .failure(let error):
                    self.startStopSpinner(start: false)
                    print("Chart for \(symbol) \(span) could not be loaded: \(error)")
                    if !showsCachedChart {
                        ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self)
                    }
                }
            }
        }

        if isIndex {
            ChartAPI.shared.getMarketValues(span: span, symbol: symbol, completion: handle)
        } else {
            ChartAPI.shared.getStockValues(span: span, symbol: symbol, completion: handle)
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
        
        setHeaderTitle(symbol: symbol, name: informationCryptoTicker.name)
        self.currentPrice = informationCryptoTicker.price
        currentPriceLabel.text = priceText(informationCryptoTicker.price)
        currentPercentageLabel.text = Self.changeText(informationCryptoTicker.change) + " Day"
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
        let points = modelCandles.map {
            PricePoint(time: $0.start_timestamp, open: $0.open, high: $0.high, low: $0.low, close: $0.close)
        }
        //A day is up or down against yesterday's close, which the header's change is measured
        //from too. Longer spans compare with their own first bar.
        let previousClose = informationStockTicker.previousPrice
        chartModel.baseline = span == "1D" && previousClose > 0 ? previousClose : nil
        chartModel.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        chartModel.axisFormat = Self.axisFormat(span: span)
        chartModel.points = points
        showBar(chartModel.drawnPoints.last)
    }
    
    private func setUpCryptoModel() {
        guard let modelCandles = cryptoData else { return }
        //A malformed candle is skipped rather than abandoning the whole chart.
        let points = modelCandles.compactMap { candle -> PricePoint? in
            guard let time = TimeInterval(candle.start_timestamp),
                  let open = Double(candle.open),
                  let high = Double(candle.max),
                  let low = Double(candle.min),
                  let close = Double(candle.close) else { return nil }
            return PricePoint(time: time, open: open, high: high, low: low, close: close)
        }
        chartModel.baseline = nil
        chartModel.timeZone = .current
        chartModel.axisFormat = Self.axisFormat(cryptoInterval: interval)
        chartModel.points = points
        showBar(chartModel.drawnPoints.last)
    }

    // MARK: - Chart (BS-327)

    ///The labels under the chart: hours for a day, weekdays for a week, then months and years.
    private static func axisFormat(span: String) -> String {
        switch span {
        case "1D": return "h a"
        case "1W": return "EEE"
        case "1M": return "d MMM"
        case "3M", "1Y": return "MMM"
        default: return "yyyy"
        }
    }

    private static func axisFormat(cryptoInterval: String) -> String {
        switch cryptoInterval {
        case "900", "3600": return "h a"
        case "18000": return "d MMM"
        default: return "MMM yy"
        }
    }

    ///The date in the header while scrubbing: the time of day where the bars are intraday.
    private func scrubDateFormat() -> String {
        if informationStockTicker.ticker.isEmpty {
            return ["900", "3600", "18000"].contains(interval) ? "d MMM, h:mm a" : "d MMM yyyy"
        }
        switch span {
        case "1D": return "h:mm a"
        case "1W": return "EEE d MMM, h:mm a"
        default: return "d MMM yyyy"
        }
    }

    ///The chart in its storyboard box, as a child view controller so SwiftUI gets the screen's
    ///trait changes (dark mode, text size). The storyboard's time labels are hidden: the chart
    ///draws its own axis. Scrubbing shows the price and date in the header, like Apple's
    ///Stocks, and the bar's open, high, low and close in the row above the chart.
    private func installChart() {
        let host = UIHostingController(rootView: PriceChartView(model: chartModel))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        chartView.insertSubview(host.view, at: 0)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: chartView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: chartView.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: chartView.trailingAnchor)
        ])
        host.didMove(toParent: self)

        for label in [oldestTimeLabel, middleTimeLabel, currentTimeLabel] {
            label?.isHidden = true
        }

        chartModel.onScrub = { [weak self] point in
            self?.showScrub(point)
        }
        choseTypeChart()
    }

    ///The bar under the finger in the header: its close where the price is, its date where the
    ///change is, and all four prices in the O/H/L/C row. Lifting the finger puts the header
    ///back exactly as it was and the row back on the latest bar.
    private func showScrub(_ point: PricePoint?) {
        showBar(point ?? chartModel.drawnPoints.last)
        guard let point else {
            if let before = headerBeforeScrub {
                currentPriceLabel.text = before.price
                currentPriceLabel.textColor = before.priceColor
                currentPercentageLabel.text = before.change
                currentPercentageLabel.textColor = before.changeColor
            }
            headerBeforeScrub = nil
            return
        }
        if headerBeforeScrub == nil {
            headerBeforeScrub = (currentPriceLabel.text, currentPriceLabel.textColor,
                                 currentPercentageLabel.text, currentPercentageLabel.textColor)
            scrubFeedback.prepare()
        }
        scrubFeedback.selectionChanged()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chartModel.timeZone
        formatter.dateFormat = scrubDateFormat()
        currentPriceLabel.text = priceText(point.close)
        currentPriceLabel.textColor = .label
        currentPercentageLabel.text = formatter.string(from: point.date)
        currentPercentageLabel.textColor = .secondaryLabel
    }

    ///One bar's open, high, low and close in the row between the action buttons and the chart,
    ///coloured by whether it closed above its open, like its candle. Empty before a chart loads.
    private func showBar(_ point: PricePoint?) {
        let labels: [(UILabel?, String, Double?)] = [(pointingOpenLabel, "O", point?.open),
                                                    (pointingHighLabel, "H", point?.high),
                                                    (pointingLowLabel, "L", point?.low),
                                                    (pointingCloseLabel, "C", point?.close)]
        let color: UIColor = (point?.close ?? 0) >= (point?.open ?? 0)
            ? (UIColor(named: "uptrend") ?? .systemGreen)
            : (UIColor(named: "downtrend") ?? .systemRed)
        for (label, letter, value) in labels {
            label?.text = value.map { "\(letter) " + priceText($0) } ?? "\(letter) —"
            label?.textColor = .label
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.7
        }
        pointingOpenLabel.textColor = color
        pointingCloseLabel.textColor = color

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = chartModel.timeZone
        formatter.dateFormat = scrubDateFormat()
        pointingDateLabel.text = point.map { formatter.string(from: $0.date) } ?? ""
        pointingDateLabel.textColor = .secondaryLabel
    }

    ///A price the way the whole screen shows it: "$1,234.56" for stocks and coins, coins under
    ///$1 with up to four decimals, and an index in points without a dollar sign ("6,612.38").
    private func priceText(_ value: Double) -> String {
        guard indexMarket, !informationStockTicker.ticker.isEmpty else { return Self.ohlcText(value) }
        return Self.pointsFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static let pointsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    ///"+1.16%" / "-0.42%": always signed, two decimals, and never "-0.00%".
    private static func changeText(_ percent: Double) -> String {
        let rounded = (percent * 100).rounded() / 100
        return String(format: "%@%.2f%%", rounded > 0 ? "+" : (rounded < 0 ? "-" : ""), abs(rounded))
    }

    ///"$334.91" for the open/high/low/close readout. The values were printed raw, and the chart
    ///server passes Yahoo's full-precision floats through, so they read "$334.9100036621094"
    ///and pushed High and Close off the row. Coins under $1 keep up to four decimals so they
    ///do not all read "$0.08".
    private static let ohlcFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static func ohlcText(_ value: Double) -> String {
        let small = abs(value) < 1
        ohlcFormatter.minimumFractionDigits = 2
        ohlcFormatter.maximumFractionDigits = small ? 4 : 2
        return ohlcFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
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
        
        let chartImage = chartModel.snapshot(size: CGSize(width: 300, height: 300), style: traitCollection.userInterfaceStyle) ?? defaultImage
                    
        let activityItems: [Any] = [formattedText, chartImage]
        
        let post = communityPost()
        let activityVC = PostToCommunity.shareSheet(items: activityItems, text: post.text, photos: post.photos, from: self)
        present(activityVC, animated: true)
        
    }

    ///What "Post to Community" starts with: the $TICKER and company name, and the chart.
    ///Crypto charts leave the stock ticker empty, and an index's "^GSPC" can't be linked.
    fileprivate func communityPost() -> (text: String, photos: [UIImage]) {
        let fields = Self.shareFields(stock: informationStockTicker, crypto: informationCryptoTicker,
                                      nameTicker: nameTicker, indexName: indexName)
        let stockTicker = informationStockTicker.ticker
        let text = PostToCommunity.chartDraft(symbol: fields.symbol, name: fields.name,
                                              ticker: stockTicker.isEmpty ? nil : stockTicker)
        let image = chartModel.snapshot(size: CGSize(width: 600, height: 400), style: traitCollection.userInterfaceStyle)
        return (text, image.map { [$0] } ?? [])
    }
    
    @IBAction func selectTypeChart(_ sender: UIButton) {
        selectedCandleChart.toggle()
        choseTypeChart()
    }
    
    ///The line/candle button shows the other style, the one a tap switches to.
    func choseTypeChart(){
        chartModel.showsCandles = selectedCandleChart
        //A merged candle has its own open, high and low; the row follows what's drawn.
        showBar(chartModel.drawnPoints.last)
        selectChartButton.setImage(UIImage(named: selectedCandleChart ? "chart.line.uptrend.xyaxis" : "chart.bar.fill"), for: .normal)
    }
    
    @IBAction func openNewsButton(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController else { return }

        if self.informationCryptoTicker.name == "" {
            let ticker = informationStockTicker.ticker
            
            if indexMarket {
                //The ticker, "^GSPC". This sent the name, "S&P 500", which the server refuses
                //as a symbol, so index news was always empty. (BS-261)
                destination.ticker = ticker
                destination.name = indexName
            } else {
                destination.ticker = ticker
                destination.name = nameTicker
            }
        } else {
            destination.ticker = informationCryptoTicker.symbol
            destination.name = informationCryptoTicker.name
        }
        
        destination.modalTransitionStyle = .crossDissolve

        let navController = UINavigationController(rootViewController: destination)
        navController.modalPresentationStyle = .pageSheet
        navController.modalTransitionStyle = .crossDissolve
        self.present(navController, animated: true)
    }
}


// MARK: - Action row (BS-286)

///News, Share, Community and Watchlist as one row of equal buttons under the price, like the
///row under a name in Contacts. The share and news icons used to float at the top right,
///apart from everything else, and the chart had no way to post about it or follow it.
///Built here rather than in Singles.storyboard so the watchlist, search and markets entry
///points keep the same scene.
extension ChartController {

    fileprivate func addActionRow() {
        //The storyboard's own icons; their actions now live in the row.
        shareButton.isHidden = true
        shareButton.superview?.subviews
            .compactMap { $0 as? UIButton }
            .filter { $0.actions(forTarget: self, forControlEvent: .touchUpInside)?.contains("openNewsButton:") == true }
            .forEach { $0.isHidden = true }

        let news = actionButton(title: "News", symbol: "newspaper") { [weak self] button in
            self?.openNewsButton(button)
        }
        let share = actionButton(title: "Share", symbol: "square.and.arrow.up") { [weak self] button in
            self?.shareButtonTapped(button)
        }
        let community = actionButton(title: "Community", symbol: PostToCommunity.symbolName) { [weak self] _ in
            self?.communityTapped()
        }
        let watchlist = actionButton(title: "Watchlist", symbol: "plus") { [weak self] button in
            self?.watchlistTapped(button)
        }
        //Crypto has its own list; the watchlist holds stocks and indexes.
        watchlist.isEnabled = !informationStockTicker.ticker.isEmpty
        updateWatchlistButton(watchlist)

        let row = UIStackView(arrangedSubviews: [news, share, community, watchlist])
        row.distribution = .fillEqually
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)

        //The O/H/L/C labels sat under the price; they now sit under the row.
        let constraints = view.constraints + (pointingViewLabels.superview?.constraints ?? [])
        for constraint in constraints where constraint.firstItem === pointingViewLabels
            && constraint.firstAttribute == .top && constraint.secondItem === currentPriceLabel {
            constraint.isActive = false
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: currentPriceLabel.bottomAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            row.heightAnchor.constraint(equalToConstant: 58),
            pointingViewLabels.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 12)
        ])
    }

    private func actionButton(title: String, symbol: String, action: @escaping (UIButton) -> Void) -> ActionTile {
        let button = ActionTile()
        button.set(title: title, symbol: symbol)
        button.addAction(UIAction { [weak button] _ in
            guard let button else { return }
            action(button)
        }, for: .touchUpInside)
        return button
    }

    // MARK: Community

    ///A stock opens what people are saying about it, with Post there (BS-287). Crypto and
    ///indexes can't be a $TICKER, so they have no posts to show and go straight to posting.
    private func communityTapped() {
        let ticker = informationStockTicker.ticker.uppercased()
        guard !indexMarket, !ticker.isEmpty, Post.tickers(in: "$\(ticker)") == [ticker] else {
            let post = communityPost()
            return PostToCommunity.start(text: post.text, photos: post.photos, from: self)
        }
        let posts = CommunityController(ticker: ticker) { [weak self] in
            self?.communityPost() ?? (text: "\n\n$\(ticker)", photos: [])
        }
        guard let navigationController else {
            return present(UINavigationController(rootViewController: posts), animated: true)
        }
        navigationController.pushViewController(posts, animated: true)
    }

    // MARK: Watchlist

    ///Asked of the store each time, so a ticker added or removed elsewhere shows right.
    private var isInWatchlist: Bool {
        let ticker = informationStockTicker.ticker
        return !ticker.isEmpty && SaveTickers().loadTickers().contains { $0.ticker == ticker }
    }

    private func updateWatchlistButton(_ button: UIButton) {
        let added = isInWatchlist
        (button as? ActionTile)?.set(title: added ? "Added" : "Watchlist", symbol: added ? "checkmark" : "plus")
        button.accessibilityLabel = added ? "Remove from Watchlist" : "Add to Watchlist"
    }

    ///Adds the stock to the active watchlist, or after asking removes it.
    private func watchlistTapped(_ button: UIButton) {
        let ticker = informationStockTicker.ticker
        guard !ticker.isEmpty else { return }
        guard isInWatchlist else {
            //Like search: no logo yet, so the watchlist fetches it.
            let name = indexMarket ? indexName : nameTicker
            let features = TickersFeatures(ticker: ticker, nameTicker: name,
                                           imageTicker: UIImage(named: "mw-logo") ?? UIImage(), imageTickerName: "")
            SaveTickers().saveTicker(tickerFeatures: features)
            //saveTicker writes on the next main-queue turn; read the store after it.
            DispatchQueue.main.async { [weak self] in self?.updateWatchlistButton(button) }
            return
        }
        let sheet = UIAlertController(title: "Remove \(Self.displaySymbol(ticker)) from your watchlist?",
                                      message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            SaveTickers().deleteTicker(ticker: ticker)
            DispatchQueue.main.async { self?.updateWatchlistButton(button) }
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = button
        present(sheet, animated: true)
    }
}


///One button of the chart's action row: an icon over a short label, centred both ways.
///A configured button's image-over-title layout sat high in the tile, as Avenir's tall line
///box pushes the title's bottom down; this centres the pair as one block instead.
private final class ActionTile: UIButton {

    private let icon = UIImageView()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        var background = UIButton.Configuration.filled()
        background.baseBackgroundColor = ProfileStyle.card
        background.cornerStyle = .large
        configuration = background

        icon.tintColor = UIColor(named: "uptrend") ?? ProfileStyle.accent
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        label.font = UIFont(name: "Avenir-Heavy", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = ProfileStyle.text
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 22),
            //Wide symbols (the two figures of Community) are scaled to the others' width.
            icon.widthAnchor.constraint(lessThanOrEqualToConstant: 24),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            //Two points low: the symbol's box has room above the glyph and Avenir's line box
            //room below the text, so the exact centre reads as high.
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(title: String, symbol: String) {
        label.text = title
        icon.image = UIImage(systemName: symbol)
        accessibilityLabel = title
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.4 }
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
