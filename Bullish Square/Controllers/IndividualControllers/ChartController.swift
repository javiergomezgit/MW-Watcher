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
    // MARK: - Views
    //Built in code and placed by layOutScreen (BS-327). The storyboard scene is an empty view:
    //its DGCharts-era parts (HBSegmentedControl, the three time labels, the floating O/H/L/C
    //box, the share and news icons) are gone, with their outlets.

    ///The box the Swift Charts chart and its loading skeleton sit in.
    let chartView = UIView()
    ///The company's name, or the symbol when the name isn't known.
    let tickerLabel = UILabel()
    ///Switches between candles and the line.
    let selectChartButton = UIButton(type: .system)
    let currentPriceLabel = UILabel()
    let currentPercentageLabel = UILabel()
    ///The previous close for a stock, a coin's volume.
    let volumeLabel = UILabel()
    ///The logo, for stocks and coins alike.
    let cryptoImage = UIImageView()
    let pointingOpenLabel = UILabel()
    let pointingLowLabel = UILabel()
    let pointingDateLabel = UILabel()
    let pointingCloseLabel = UILabel()
    let pointingHighLabel = UILabel()
    
    ///Candles by default: they show the open, high and low a line hides.
    var selectedCandleChart = true
    
    ///A coin's time span, one of `cryptoSpans` (BS-327). The first chart is a day, like a stock's.
    var cryptoSpan = "1D"
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

    ///The time spans (stocks) or candle sizes (crypto), a native control under the chart. It
    ///replaced the storyboard's HBSegmentedControl.
    private let spanPicker = UISegmentedControl()
    ///Where the Key stats, Analysts and Health cards go (BS-327 step 4, BS-309, BS-310).
    let cardsStack = UIStackView()
    fileprivate let scrollView = UIScrollView()
    fileprivate let column = UIStackView()
    fileprivate let logoCircle = UIView()
    fileprivate lazy var chartHeight = chartView.heightAnchor.constraint(equalToConstant: Self.minimumChartHeight)
    fileprivate static let minimumChartHeight: CGFloat = 300

    ///Stocks and indexes only; crypto has no card (BS-327 decision).
    private let keyStatsCard = KeyStatsCard()
    private var keyStats = KeyStats()
    ///Stocks only: indexes and crypto have no analysts. Hidden until there's a consensus to show,
    ///and for good when none covers the stock (SPY, small caps).
    private let analystCard = AnalystCard()
    ///Stocks and indexes; crypto has no 200-day history on the server. Hidden until its first
    ///answer, so the cards below don't jump while it loads.
    private let healthCard = HealthCard()
    private var healthAnswer: StockHealthAnswer?
    ///Opened from a trend alert (BS-314): scrolls to the Health card once it has loaded.
    var scrollsToHealth = false
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitChartToScreen()
    }

    // MARK: - Tab bar hairline

    ///The tab bar's own appearance while this screen covers it, put back when it leaves.
    private var savedTabBarAppearance: UITabBarAppearance?

    ///The page scrolls under the tab bar. Whenever the cards ran past its top edge, iOS switched
    ///the bar from its clear edge look to its standard one, which draws a grey hairline across
    ///the screen above the tabs. Black page, no line: the line is turned off here only.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Back from Settings → Notifications, where trend alerts may have been turned on.
        if healthAnswer?.health != nil { refreshAlertBell() }
        guard savedTabBarAppearance == nil, let tabBar = tabBarController?.tabBar else { return }
        savedTabBarAppearance = tabBar.standardAppearance
        let appearance = tabBar.standardAppearance.copy()
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let saved = savedTabBarAppearance else { return }
        tabBarController?.tabBar.standardAppearance = saved
        savedTabBarAppearance = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isCrypto = informationStockTicker.ticker.isEmpty
        let segments = isCrypto ? Self.cryptoSpans.map(\.title) : ChartAPI.spans
        for (index, title) in segments.enumerated() {
            spanPicker.insertSegment(withTitle: title, at: index, animated: false)
        }
        spanPicker.selectedSegmentIndex = 0
        spanPicker.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)

        layOutScreen()
        startStopSpinner(start: true)
        navigationItem.title = nameTicker
        installChart()
        
        if isCrypto {
            selectedCryptoTicker()
        } else {
            if loadsQuoteAndLogo {
                loadQuoteAndLogo()
            }
            selectedStockTicker()
            loadCompanyNameIfNeeded()
            cardsStack.addArrangedSubview(keyStatsCard)
            loadKeyStats()
            healthCard.isHidden = true
            healthCard.onSelect = { [weak self] topic in self?.openHealthExplanation(topic) }
            healthCard.onBell = { [weak self] in self?.bellTapped() }
            cardsStack.addArrangedSubview(healthCard)
            loadHealth()
            if !indexMarket {
                analystCard.isHidden = true
                analystCard.onTap = { [weak self] in self?.openAnalystSheet() }
                cardsStack.addArrangedSubview(analystCard)
                loadAnalystTarget()
            }
        }
    }

    // MARK: - Health (BS-310)

    ///One request per opening; the server keeps health until the next close. Decoration: a
    ///failure shows a sentence in the card and gates nothing.
    private func loadHealth() {
        let ticker = informationStockTicker.ticker
        guard !ticker.isEmpty else { return }
        StockAPI.shared.getStockHealth(ticker: ticker) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                let answer: StockHealthAnswer
                switch result {
                case .success(let found):
                    answer = found
                case .failure(let error):
                    print("Health for \(ticker) failed; the card says so: \(error)")
                    answer = .unavailable
                }
                //A symbol the provider doesn't know has nothing to explain.
                guard answer != .noData else { return }
                self.healthAnswer = answer
                self.healthCard.update(answer, priceText: self.priceText,
                                       change: HealthSeenStore.shared.latestChange(for: ticker))
                self.healthCard.isHidden = false
                self.refreshAlertBell()
                if self.scrollsToHealth {
                    self.scrollsToHealth = false
                    self.view.layoutIfNeeded()
                    let frame = self.healthCard.convert(self.healthCard.bounds, to: self.scrollView)
                    self.scrollView.scrollRectToVisible(frame.insetBy(dx: 0, dy: -12), animated: true)
                }
            }
        }
    }

    // MARK: - Trend alerts (BS-314)

    ///Off in Settings, muted for this stock, or on. Hidden when signed out.
    private func refreshAlertBell() {
        let push = PushNotifications.shared
        guard push.isSignedIn else { return healthCard.showAlerts(nil) }
        let ticker = informationStockTicker.ticker
        push.preferences { [weak self] preferences in
            guard let self, self.informationStockTicker.ticker == ticker else { return }
            let anyOn = PushNotifications.Kind.trends.contains { preferences[$0] == true }
            guard anyOn else { return self.healthCard.showAlerts(.off) }
            push.isMuted(ticker) { [weak self] muted in
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                self.healthCard.showAlerts(muted ? .muted : .on)
            }
        }
    }

    ///With alerts off it offers Settings; otherwise it mutes or unmutes this stock, shown at once
    ///and put back if the save fails.
    private func bellTapped() {
        let push = PushNotifications.shared
        let ticker = informationStockTicker.ticker
        push.preferences { [weak self] preferences in
            guard let self else { return }
            guard PushNotifications.Kind.trends.contains(where: { preferences[$0] == true }) else {
                let alert = UIAlertController(title: "Trend Alerts Are Off",
                                              message: "Turn them on to hear when a stock on your watchlists breaks its trend or gets back in an uptrend.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
                alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
                    self?.navigationController?.pushViewController(NotificationSettingsController(), animated: true)
                })
                return self.present(alert, animated: true)
            }
            push.isMuted(ticker) { [weak self] muted in
                guard let self else { return }
                self.healthCard.showAlerts(muted ? .on : .muted)
                UIAccessibility.post(notification: .announcement,
                                     argument: muted ? "Trend alerts on for \(ticker)" : "Trend alerts muted for \(ticker)")
                push.setMuted(ticker, muted: !muted) { [weak self] error in
                    guard let self, error != nil else { return }
                    self.healthCard.showAlerts(muted ? .muted : .on)
                    Utilities.showAlert(on: self, title: "Can't Save", message: "Check your connection and try again.")
                }
            }
        }
    }

    private func openHealthExplanation(_ topic: HealthTopic) {
        guard let health = healthAnswer?.health else { return }
        let detail = HealthExplanationController(ticker: Self.displaySymbol(informationStockTicker.ticker),
                                                 health: health, topic: topic,
                                                 priceText: { [weak self] in self?.priceText($0) ?? Self.ohlcText($0) })
        let navigationController = UINavigationController(rootViewController: detail)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    // MARK: - Analysts (BS-309)

    ///Shows what the store already knows at once, then asks the server only when that is more
    ///than a day old. Decoration: a failed request keeps whatever was shown and gates nothing.
    private func loadAnalystTarget() {
        let ticker = informationStockTicker.ticker
        guard !ticker.isEmpty else { return }
        showAnalystCard()
        guard AnalystTargetStore.shared.needsFetch(ticker) else { return }
        StockAPI.shared.getAnalystTarget(ticker: ticker) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let target):
                    AnalystTargetStore.shared.record(target, for: ticker)
                case .failure(let error):
                    print("Analyst target for \(ticker) failed; the card keeps what it had: \(error)")
                }
                guard let self, self.informationStockTicker.ticker == ticker else { return }
                self.showAnalystCard()
            }
        }
    }

    ///The header's price, or nil while it is still loading.
    private var analystPrice: Double? {
        let price = informationStockTicker.marketPrice
        return !awaitingQuote && price > 0 ? price : nil
    }

    ///Also called when the header's price lands, so the upside appears with it.
    private func showAnalystCard() {
        guard !indexMarket,
              let target = AnalystTargetStore.shared.entry(for: informationStockTicker.ticker)?.target else {
            analystCard.isHidden = true
            return
        }
        analystCard.update(target, price: analystPrice)
        analystCard.isHidden = false
    }

    private func openAnalystSheet() {
        let ticker = informationStockTicker.ticker
        guard let entry = AnalystTargetStore.shared.entry(for: ticker), let target = entry.target else { return }
        let detail = AnalystTargetController(ticker: ticker,
                                             companyName: nameTicker,
                                             currentPrice: analystPrice,
                                             target: target,
                                             fetchedAt: entry.fetchedAt)
        let navigationController = UINavigationController(rootViewController: detail)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    // MARK: - Key stats (BS-327)

    ///Fills the Key stats card from the 1D and 1Y bars, which the chart usually has cached
    ///already: it opens on 1D. Decoration: a failed load leaves dashes and gates nothing.
    private func loadKeyStats() {
        let ticker = informationStockTicker.ticker
        let isIndex = indexMarket
        for span in ["1D", "1Y"] {
            candles(symbol: ticker, span: span, isIndex: isIndex) { [weak self] bars in
                guard let self, self.informationStockTicker.ticker == ticker, !bars.isEmpty else { return }
                if span == "1D" {
                    self.keyStats.setSession(bars)
                } else {
                    self.keyStats.setYear(bars)
                }
                self.keyStatsCard.update(self.keyStats, priceText: self.priceText)
            }
        }
    }

    ///A span's bars from ChartCache while fresh, else from the server, stored for the chart
    ///too. Completes exactly once, on the main queue; an empty array when they couldn't load.
    private func candles(symbol: String, span: String, isIndex: Bool, completion: @escaping ([ValueStock]) -> Void) {
        if let cached = ChartCache.shared.entry(symbol: symbol, span: span, isIndex: isIndex),
           !ChartCache.shared.isStale(cached, span: span) {
            completion(cached.values)
            return
        }
        let handle: (Result<[ValueStock], Error>) -> Void = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let bars) where !bars.isEmpty:
                    ChartCache.shared.store(bars, symbol: symbol, span: span, isIndex: isIndex)
                    completion(bars)
                case .success:
                    completion([])
                case .failure(let error):
                    print("Key stats for \(symbol) \(span) could not be loaded: \(error)")
                    completion([])
                }
            }
        }
        if isIndex {
            ChartAPI.shared.getMarketValues(span: span, symbol: symbol, completion: handle)
        } else {
            ChartAPI.shared.getStockValues(span: span, symbol: symbol, completion: handle)
        }
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
        
        let index = spanPicker.selectedSegmentIndex

        if informationStockTicker.ticker == "" {
            //Stocks decide for themselves in loadStockPrices: a cached timeframe shows no
            //loading state at all.
            guard Self.cryptoSpans.indices.contains(index) else { return }
            startStopSpinner(start: true)
            cryptoSpan = Self.cryptoSpans[index].title
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
                self.showLogo(image)
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
            showLogo(imageCompany)
            for label in [currentPriceLabel, currentPercentageLabel, volumeLabel] {
                label.text = "—"
                label.textColor = .secondaryLabel
            }
            return
        }

        if percentageChange < 0.0 {
            currentPercentageLabel.textColor = UIColor(named: "downtrend") ?? .systemRed
        } else {
            currentPercentageLabel.textColor = UIColor(named: "uptrend") ?? .systemGreen
        }
        //Like Apple's Stocks: the price in the text colour, the change in green or red.
        currentPriceLabel.textColor = .label
        volumeLabel.textColor = .secondaryLabel
        
        self.symbol = symbol
        if indexMarket {
            setHeaderTitle(symbol: Self.displaySymbol(symbol))
            volumeLabel.text = ""
        } else {
            //The symbol alone. The header used to add " - <exchange>", but the chart
            //endpoint stopped sending an exchange name, so it only ever showed a dangling dash.
            setHeaderTitle(symbol: symbol)
            volumeLabel.text = previousPrice > 0 ? "Prev. close " + priceText(previousPrice) : ""
        }
        showLogo(imageCompany)
        //Formatted like the scrubbed price, which used to be the only formatted one: the
        //header first showed raw doubles such as 271.4900016.
        currentPriceLabel.text = priceText(currentPrice)
        currentPercentageLabel.text = Self.changeText(percentageChange)
        showAnalystCard()
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
            currentPercentageLabel.textColor = UIColor(named: "downtrend") ?? .systemRed
        } else {
            currentPercentageLabel.textColor = UIColor(named: "uptrend") ?? .systemGreen
        }
        currentPriceLabel.textColor = .label
        volumeLabel.textColor = .secondaryLabel
        
        setHeaderTitle(symbol: symbol, name: informationCryptoTicker.name)
        self.currentPrice = informationCryptoTicker.price
        currentPriceLabel.text = priceText(informationCryptoTicker.price)
        currentPercentageLabel.text = Self.changeText(informationCryptoTicker.change) + " Day"
//        nameLabel.text = informationCryptoTicker.name.uppercased()
        volumeLabel.text = "Vol.\(informationCryptoTicker.volume) MM"
        showLogo(UIImage(named: informationCryptoTicker.cryptoImageName))
        
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
        //Captured before the request: a quick second tap asks for another span, and the
        //answer for the first one must not draw over it.
        let requestedSpan = cryptoSpan
        let size = Self.cryptoSpan(requestedSpan)
        CryptoAPI.shared.getSelectedCrypto(interval: size.interval, symbol: symbol) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                
                DispatchQueue.main.async {
                    guard requestedSpan == self.cryptoSpan else { return }
                    self.startStopSpinner(start: false)
                    if data.count != 0 {
                        self.cryptoData = Array(data.suffix(size.candles))
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
        //The phone's own clock, so 10:38 reads 10:38 wherever the person is. New York time
        //(the exchange's) read three hours ahead in California.
        chartModel.timeZone = .current
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
        chartModel.axisFormat = Self.axisFormat(span: cryptoSpan)
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

    ///A coin's time spans, named like a stock's. The server sends only the newest 60 candles
    ///of a size (300, 900, 3600 or 18000 seconds, week, month), so each span takes the size
    ///whose 60 candles cover it and keeps the ones inside it. There's no 1M: 5-hour candles
    ///reach 12 days and weekly ones would leave four candles.
    static let cryptoSpans: [(title: String, interval: String, candles: Int)] = [
        ("1D", "3600", 24),   //hourly
        ("1W", "18000", 34),  //5-hour, 34 x 5h is about 7 days
        ("3M", "week", 13),
        ("1Y", "week", 52),
        ("5Y", "month", 60)
    ]

    private static func cryptoSpan(_ title: String) -> (title: String, interval: String, candles: Int) {
        cryptoSpans.first { $0.title == title } ?? cryptoSpans[0]
    }

    ///The date in the header while scrubbing: the time of day where the bars are intraday.
    ///A coin's spans have the same names as a stock's and the same formats.
    private func scrubDateFormat() -> String {
        let span = informationStockTicker.ticker.isEmpty ? cryptoSpan : self.span
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
    
    func shareButtonTapped(_ sender: UIButton) {
        
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
    
    @objc func selectTypeChart(_ sender: UIButton) {
        selectedCandleChart.toggle()
        choseTypeChart()
    }
    
    ///The line/candle button shows the other style, the one a tap switches to.
    func choseTypeChart(){
        chartModel.showsCandles = selectedCandleChart
        //A merged candle has its own open, high and low; the row follows what's drawn.
        showBar(chartModel.drawnPoints.last)
        let symbol = selectedCandleChart ? "chart.xyaxis.line" : "chart.bar.xaxis"
        selectChartButton.setImage(UIImage(systemName: symbol), for: .normal)
        selectChartButton.accessibilityLabel = selectedCandleChart ? "Show line chart" : "Show candles"
    }
    
    func openNewsButton(_ sender: UIButton) {
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


// MARK: - Layout (BS-327)

///The screen as one scrolling column, like a stock in Apple's Stocks: name and logo, the price
///and its change, the action row, the open/high/low/close row, the chart, the span picker under
///it, then cards. Built in code from the storyboard's own views, which keeps every outlet and
///every entry point working; the storyboard's other views (the old picker, time labels and
///icons) are hidden.
extension ChartController {

    fileprivate func layOutScreen() {
        view.backgroundColor = .systemBackground
        //The symbol sits small in the bar. As a large title it took a row of its own above the
        //company name, with nothing beside it.
        navigationItem.largeTitleDisplayMode = .never
        let views: [UIView] = [cryptoImage, tickerLabel, currentPriceLabel, currentPercentageLabel, volumeLabel,
                               chartView, selectChartButton, pointingDateLabel, pointingOpenLabel,
                               pointingHighLabel, pointingLowLabel, pointingCloseLabel]
        for item in views {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        selectChartButton.addTarget(self, action: #selector(selectTypeChart(_:)), for: .touchUpInside)

        //Name and logo. The logo sits inside a circle with room around it: drawn edge to edge,
        //round logos such as Apple's touched the circle. The circle takes the logo's own
        //background colour (`showLogo`), so a square logo doesn't show as a square.
        cryptoImage.contentMode = .scaleAspectFit
        logoCircle.backgroundColor = .secondarySystemBackground
        logoCircle.layer.cornerRadius = 22
        logoCircle.clipsToBounds = true
        logoCircle.addSubview(cryptoImage)
        NSLayoutConstraint.activate([
            logoCircle.widthAnchor.constraint(equalToConstant: 44),
            logoCircle.heightAnchor.constraint(equalToConstant: 44),
            cryptoImage.widthAnchor.constraint(equalToConstant: 32),
            cryptoImage.heightAnchor.constraint(equalToConstant: 32),
            cryptoImage.centerXAnchor.constraint(equalTo: logoCircle.centerXAnchor),
            cryptoImage.centerYAnchor.constraint(equalTo: logoCircle.centerYAnchor)
        ])
        Self.style(tickerLabel, .title1, weight: .bold, color: .label)
        tickerLabel.alpha = 1
        let nameRow = UIStackView(arrangedSubviews: [logoCircle, tickerLabel])
        nameRow.spacing = 10
        nameRow.alignment = .center

        //Price, change and the previous close (or a coin's volume).
        Self.style(currentPriceLabel, .largeTitle, weight: .bold, color: .label)
        Self.style(currentPercentageLabel, .headline, weight: .semibold, color: .secondaryLabel)
        Self.style(volumeLabel, .subheadline, weight: .regular, color: .secondaryLabel)
        let changeRow = UIStackView(arrangedSubviews: [currentPercentageLabel, volumeLabel, UIView()])
        changeRow.spacing = 10
        changeRow.alignment = .firstBaseline

        //Open, high, low and close of the latest bar, or of the one under the finger.
        for label in [pointingOpenLabel, pointingHighLabel, pointingLowLabel, pointingCloseLabel] {
            Self.style(label, .callout, weight: .semibold, color: .label)
            label.textAlignment = .center
        }
        Self.style(pointingDateLabel, .subheadline, weight: .regular, color: .secondaryLabel)
        pointingDateLabel.textAlignment = .center
        let prices = UIStackView(arrangedSubviews: [pointingOpenLabel, pointingHighLabel, pointingLowLabel, pointingCloseLabel])
        prices.distribution = .fillEqually
        prices.spacing = 4
        let barRow = UIStackView(arrangedSubviews: [pointingDateLabel, prices])
        barRow.axis = .vertical
        barRow.spacing = 2
        barRow.alignment = .fill

        //The chart, then the spans with the candle/line switch beside them.
        chartView.backgroundColor = .clear
        //Sized in viewDidLayoutSubviews: at least 300 points, taller to fill the screen.
        chartHeight.isActive = true
        selectChartButton.tintColor = UIColor(named: "colorAccent") ?? .tintColor
        NSLayoutConstraint.activate([
            selectChartButton.widthAnchor.constraint(equalToConstant: 44),
            selectChartButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        let pickerRow = UIStackView(arrangedSubviews: [spanPicker, selectChartButton])
        pickerRow.spacing = 8
        pickerRow.alignment = .center

        cardsStack.axis = .vertical
        cardsStack.spacing = 12

        let items: [UIView] = [nameRow, currentPriceLabel, changeRow, makeActionRow(), barRow, chartView, pickerRow, cardsStack]
        for item in items {
            column.addArrangedSubview(item)
        }
        column.axis = .vertical
        column.spacing = 12
        column.setCustomSpacing(8, after: nameRow)
        column.setCustomSpacing(2, after: currentPriceLabel)
        column.setCustomSpacing(16, after: changeRow)
        column.setCustomSpacing(16, after: barRow)
        column.setCustomSpacing(20, after: pickerRow)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scroll = scrollView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        //A touch on the chart goes straight to its selection; scrolling still works off it.
        scroll.delaysContentTouches = false
        view.addSubview(scroll)
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    ///Grows the chart to fill whatever height the screen has left, so there is no empty band
    ///under the picker, and never shrinks it below 300 points: once cards fill the page, the
    ///chart stays 300 and the page scrolls. Set directly: asking the stack view to stretch the
    ///chart (by hugging priority) left the band in place on device.
    fileprivate func fitChartToScreen() {
        guard column.superview != nil else { return }
        let visible = scrollView.bounds.height - scrollView.adjustedContentInset.top
            - scrollView.adjustedContentInset.bottom - 32
        let others = column.bounds.height - chartHeight.constant
        let height = max(Self.minimumChartHeight, (visible - others).rounded(.down))
        if abs(height - chartHeight.constant) > 0.5 {
            chartHeight.constant = height
        }
    }

    ///The logo, on a circle of the logo's own background colour, read from its top-left
    ///pixel. Most logos are squares on white or a brand colour; on a grey circle that square
    ///showed. A transparent corner keeps the grey.
    fileprivate func showLogo(_ image: UIImage?) {
        cryptoImage.image = image
        logoCircle.backgroundColor = image?.cornerColor() ?? .secondarySystemBackground
    }

    ///System text styles, so the screen follows the person's text size (Dynamic Type).
    private static func style(_ label: UILabel?, _ textStyle: UIFont.TextStyle, weight: UIFont.Weight, color: UIColor) {
        guard let label else { return }
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        let font = UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: weight)
        label.font = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 1
    }
}

// MARK: - Action row (BS-286)

///News, Share, Community and Watchlist as one row of equal buttons under the price, like the
///row under a name in Contacts. The share and news icons used to float at the top right,
///apart from everything else, and the chart had no way to post about it or follow it.
///Built here rather than in Singles.storyboard so the watchlist, search and markets entry
///points keep the same scene.
extension ChartController {

    fileprivate func makeActionRow() -> UIStackView {
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
        row.heightAnchor.constraint(equalToConstant: 58).isActive = true
        return row
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
    ///The colour of the top-left pixel, or nil where it is see-through: a logo's background.
    func cornerColor() -> UIColor? {
        guard let cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            //Draws the whole image shifted so only its top-left pixel lands in the 1x1 context.
            context.draw(cgImage, in: CGRect(x: 0, y: -CGFloat(cgImage.height - 1),
                                             width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
            return true
        }
        guard drawn, pixel[3] > 200 else { return nil }
        let alpha = CGFloat(pixel[3]) / 255
        return UIColor(red: CGFloat(pixel[0]) / 255 / alpha, green: CGFloat(pixel[1]) / 255 / alpha,
                       blue: CGFloat(pixel[2]) / 255 / alpha, alpha: 1)
    }

    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
