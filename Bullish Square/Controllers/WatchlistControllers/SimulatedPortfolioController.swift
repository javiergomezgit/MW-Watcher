//
//  SimulatedPortfolioController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 3/25/23.
//

import UIKit

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
    
    ///The storyboard's slot for the time picker. It held an HBSegmentedControl; the native
    ///control below is placed in it instead (BS-328).
    @IBOutlet weak var timesContainer: UIView!
    private let timesSegmentedControl = UISegmentedControl(items: ["1 day", "1 month", "1 year", "5 years"])
    
    var marketsPrices = [GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0)]
    let savedTickers = SaveTickers()
    var vixTodayPrice = 0.0
    var nasdaqTodayPrice = 0.0
    var sp500TodayPrice = 0.0
    var dowTodayPrice = 0.0
    var timeRange = "&interval=15m&range=1d"
    
    ///Percent change per time slot for each line.
    private var linearValuesSP500: [Double] = []
    private var linearValuesDJI: [Double] = []
    private var linearValuesIXIC: [Double] = []
    private var linearValuesPortfolio: [Double] = []

    ///The indexes and the portfolio, in Swift Charts (BS-328). Made on first use, inside `chartView`.
    private lazy var chartModel = ComparisonChartModel.install(in: chartView, parent: self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setSegementedControl()
        
        if let tickers = loadPortfolioTickers() {
            loadCurrentPrices(tickers: tickers)
        } else {
            showEmptyPortfolioState()
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
    
    ///A native segmented control filling the storyboard's slot, like the stock chart's picker.
    private func setSegementedControl() {
        timesContainer.backgroundColor = .clear
        timesSegmentedControl.selectedSegmentIndex = 0
        timesSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        timesContainer.addSubview(timesSegmentedControl)
        NSLayoutConstraint.activate([
            timesSegmentedControl.topAnchor.constraint(equalTo: timesContainer.topAnchor),
            timesSegmentedControl.bottomAnchor.constraint(equalTo: timesContainer.bottomAnchor),
            timesSegmentedControl.leadingAnchor.constraint(equalTo: timesContainer.leadingAnchor),
            timesSegmentedControl.trailingAnchor.constraint(equalTo: timesContainer.trailingAnchor)
        ])
        timesSegmentedControl.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)
    }
    
    

    
    
    @objc func segmentValueChanged(_ sender: AnyObject?){
        
        startStopSpinner(start: true)
        
        let index = timesSegmentedControl.selectedSegmentIndex
        
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
        } else {
            //There is nothing to fetch, so the spinner started above would otherwise spin
            //forever and lock the screen behind its overlay.
            startStopSpinner(start: false)
            showEmptyPortfolioState()
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
        ChartAPI.shared.getPricesMarketsAndWatchlist(tickersWatchlist: tickers, timeRange: timeRange) { [weak self] markets in
            //This completion arrives on a URLSession queue. Removing the spinner touches the
            //view hierarchy and the alert presents UI, so neither may run off main.
            DispatchQueue.main.async {
                guard let self else { return }
                self.startStopSpinner(start: false)
                
                guard let marketsValues = markets else {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                    return
                }
                
                self.linearValuesSP500.removeAll()
                self.linearValuesDJI.removeAll()
                self.linearValuesIXIC.removeAll()
                self.linearValuesPortfolio.removeAll()
                
                self.processPricesPerformance(marketsValues: marketsValues)
            }
        }
    }
    
    ///Shown when the watchlist holds nothing to measure. Without this the storyboard's
    ///placeholder zeros stay on screen and read as a real flat result, claiming the portfolio
    ///is positive and level with every index.
    private func showEmptyPortfolioState() {
        sp500TodayLabel.text = "—"
        dowTodayLabel.text = "—"
        nasdaqTodayLabel.text = "—"
        
        sp500ComparingLabel.text = "—"
        dowComparingLabel.text = "—"
        nasdaqComparingLabel.text = "—"
        myPortfolioComparingLabel.text = "—"
        
        //These sit inside sentences laid out in the storyboard: "The Portfolio is <x>" and
        //"<y> S&P 500 with <z>", so the wording has to complete them.
        sp500OverLabel.text = ""
        dowOverLabel.text = ""
        nasdaqOverLabel.text = ""
        myPortfolioOverLabel.text = "empty"
    }
    
    func processPricesPerformance(marketsValues: [PerformersPrices]){
        
        var sumPortfolio = 0.0
        var pricesAndTimes = [PerformersPrices]()
        
        for marketValue in marketsValues {
            //print("\(marketValue.ticker): \(marketValue.tickerPerformer.map { $0.close })")
            let ticker = marketValue.ticker
            switch ticker {
            case "^DJI":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "DOW JONES", indexPrice: market., changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.dowTodayPrice = percentage
                dowTodayLabel.text = String("\(percentage)%")
                for lineValue in marketValue.tickerPerformer {
                    let closePrice = lineValue.close
                    self.linearValuesDJI.append(closePrice)
                }
                break
            case "^GSPC":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "S&P 500", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.sp500TodayPrice = percentage
                sp500TodayLabel.text = String("\(percentage)%")
                for lineValue in marketValue.tickerPerformer {
                    let closePrice = lineValue.close
                    self.linearValuesSP500.append(closePrice)
                }
                break
            case "^IXIC":
                //let marketInfo = GeneralMarkets(indexTicker: ticker, indexName: "NASDAQ", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                let percentage = marketValue.changePercentage
                self.nasdaqTodayPrice = percentage
                nasdaqTodayLabel.text = String("\(percentage)%")
                for lineValue in marketValue.tickerPerformer {
                    let closePrice = lineValue.close
                    self.linearValuesIXIC.append(closePrice)
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
        
        //A watchlist holding only index symbols leaves nothing to average, and 0/0 put "nan%"
        //into every label. Report no performance instead, and render a dash so an empty
        //portfolio is not mistaken for a flat 0%.
        let hasPortfolio = !pricesAndTimes.isEmpty
        let portfolioPerformance = hasPortfolio ? sumPortfolio / Double(pricesAndTimes.count) : 0.0
        
        let dowCompareTo = portfolioPerformance - self.dowTodayPrice
        let sp500CompareTo = portfolioPerformance - self.sp500TodayPrice
        let nasdaqCompareTo = portfolioPerformance - self.nasdaqTodayPrice
        
        func percentText(_ value: Double) -> String {
            guard hasPortfolio, value.isFinite else { return "—" }
            return "\(Double(round(100*value)/100))%"
        }
                
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
            
            if !hasPortfolio {
                //Nothing to compare against yet; the over/under wording would otherwise claim
                //the portfolio is outperforming on a value that does not exist.
                self.dowOverLabel.text = ""
                self.sp500OverLabel.text = ""
                self.nasdaqOverLabel.text = ""
                self.myPortfolioOverLabel.text = "empty"
            }
            
            self.dowComparingLabel.text = percentText(dowCompareTo)
            self.sp500ComparingLabel.text = percentText(sp500CompareTo)
            self.nasdaqComparingLabel.text = percentText(nasdaqCompareTo)
            self.myPortfolioComparingLabel.text = percentText(portfolioPerformance)
            //self.refreshControl.endRefreshing()
            //self.startStopSpinner(start: false)
            self.loadPerformerChart()
        }
    }
    
    private func populatePortfolioChartEntry(portfolioStocks: [PerformersPrices]) {
        
        var sumPerSlot: [Int: Double] = [:]
        var countPerSlot: [Int: Int] = [:]
        
        for stock in portfolioStocks {
            for (i, closePrices) in stock.tickerPerformer.enumerated() {
                let closePrice = closePrices.close
                guard closePrice != 0 else { continue }
                sumPerSlot[i, default: 0] += closePrice
                countPerSlot[i, default: 0] += 1
            }
        }
        
        linearValuesPortfolio.removeAll()
        
        //Use max slot count instead of only slots with data
        let maxSlot = portfolioStocks.map { $0.tickerPerformer.count }.max() ?? 0
        
        for i in 0..<maxSlot {
            let sum = sumPerSlot[i] ?? 0
            let count = countPerSlot[i] ?? 0
            
            guard count > 0 else {
                //Fill gap with previous value — keeps chart line continuous
                let previousY = linearValuesPortfolio.last ?? 0
                print("Slot \(i): GAP FILLED with \(previousY)")

                linearValuesPortfolio.append(previousY)
                continue
            }
            
            let avg = sum / Double(count)
            print("Slot \(i): avg=\(avg) count=\(count)")
            linearValuesPortfolio.append(avg)
        }
        print("populatePortfolioChartEntry running — maxSlot: \(portfolioStocks.map { $0.tickerPerformer.count }.max() ?? 0)")
    }
}

// MARK: - Chart

extension SimulatedPortfolioController {

    ///The three indexes thin and smooth, the portfolio thick with a dot per value, all as
    ///percent change over the picked span. The axis fits the lines and always shows 0%.
    func loadPerformerChart() {
        chartModel.series = [
            ComparisonSeries(name: "S&P 500", color: .systemOrange, values: linearValuesSP500, lineWidth: 1),
            ComparisonSeries(name: "Dow Jones", color: .systemBrown, values: linearValuesDJI, lineWidth: 1),
            ComparisonSeries(name: "Nasdaq", color: .systemBlue, values: linearValuesIXIC, lineWidth: 1),
            ComparisonSeries(name: "Portfolio", color: .label, values: linearValuesPortfolio, lineWidth: 2, showsPoints: true)
        ]
    }
}
