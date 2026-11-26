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
    ///Named like the stock chart's spans. The server allows these four ranges for this screen.
    private let timesSegmentedControl = UISegmentedControl(items: ["1D", "1M", "1Y", "5Y"])
    
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
                    //Usually the price provider being busy for the longer spans, which the server
                    //can't fill from quotes. The span picked stays selected; another try later works.
                    ShowAlerts.showSimpleAlert(title: "Prices unavailable",
                                               message: "Prices for this span couldn't be loaded right now. Try again in a few minutes.",
                                               titleButton: "OK", over: self)
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
    
    ///The three indexes, the VIX (fetched, not shown) and the watchlist's stocks, from one answer.
    private static let indexTickers: Set<String> = ["^DJI", "^GSPC", "^IXIC", "^VIX"]

    ///Every headline number is the last point of its line, so the words can't disagree with the
    ///chart. Both come from the same baseline (`ChartAPI.loadPerformers`), and the portfolio is
    ///the plain average of its stocks' changes, at the end and at every point of the line.
    func processPricesPerformance(marketsValues: [PerformersPrices]){
        let byTicker = Dictionary(marketsValues.map { ($0.ticker, $0) }, uniquingKeysWith: { first, _ in first })
        let portfolioStocks = marketsValues.filter { !Self.indexTickers.contains($0.ticker) }

        //One clock for every line, so the portfolio and the indexes are compared at the same
        //moments. Lines used to be matched by bar number, and a stock missing a bar shifted
        //everything after it. The clock is the indexes' own bars, the market's session: a coin
        //on the list trades all day and on weekends, and its extra bars would stretch the 1D
        //axis over 24 hours and put flat weekend steps into every other line.
        let indexClock = ["^GSPC", "^DJI", "^IXIC"].compactMap { byTicker[$0]?.tickerPerformer.map(\.timeStamp) }
        let clockSource = indexClock.isEmpty ? marketsValues.map { $0.tickerPerformer.map(\.timeStamp) } : indexClock
        let timeline = Array(Set(clockSource.flatMap { $0 })).sorted()
        linearValuesDJI = Self.line(byTicker["^DJI"]?.tickerPerformer, on: timeline)
        linearValuesSP500 = Self.line(byTicker["^GSPC"]?.tickerPerformer, on: timeline)
        linearValuesIXIC = Self.line(byTicker["^IXIC"]?.tickerPerformer, on: timeline)
        linearValuesPortfolio = Self.averageLine(portfolioStocks.map(\.tickerPerformer), on: timeline)

        //A missing index shows a dash rather than keeping the previous span's number.
        let dow = byTicker["^DJI"]?.changePercentage
        let sp500 = byTicker["^GSPC"]?.changePercentage
        let nasdaq = byTicker["^IXIC"]?.changePercentage
        self.dowTodayPrice = dow ?? 0
        self.sp500TodayPrice = sp500 ?? 0
        self.nasdaqTodayPrice = nasdaq ?? 0
        self.vixTodayPrice = byTicker["^VIX"]?.changePercentage ?? 0
        dowTodayLabel.text = dow.map(Self.percentText) ?? "—"
        sp500TodayLabel.text = sp500.map(Self.percentText) ?? "—"
        nasdaqTodayLabel.text = nasdaq.map(Self.percentText) ?? "—"

        //nil with no stocks: an empty portfolio is not a flat 0%.
        let portfolio: Double? = portfolioStocks.isEmpty ? nil
            : portfolioStocks.map(\.changePercentage).reduce(0, +) / Double(portfolioStocks.count)

        showComparison(portfolio: portfolio, index: dow, comparing: dowComparingLabel, over: dowOverLabel)
        showComparison(portfolio: portfolio, index: sp500, comparing: sp500ComparingLabel, over: sp500OverLabel)
        showComparison(portfolio: portfolio, index: nasdaq, comparing: nasdaqComparingLabel, over: nasdaqOverLabel)

        if let portfolio {
            myPortfolioComparingLabel.text = Self.percentText(portfolio)
            //"The Portfolio is <up/down>": its own move over the span, not a comparison.
            myPortfolioOverLabel.text = portfolio < 0 ? "Underperforming" : "Overperforming"
            myPortfolioOverLabel.textColor = portfolio < 0 ? UIColor(named: "downtrend") : UIColor(named: "uptrend")
        } else {
            myPortfolioComparingLabel.text = "—"
            myPortfolioOverLabel.text = "empty"
        }
        loadPerformerChart()
    }

    ///"<difference> <Over/Underperforming the> <index>". The difference is portfolio minus
    ///index, both rounded the way they're shown, so the sign always matches the numbers on screen.
    private func showComparison(portfolio: Double?, index: Double?, comparing: UILabel, over: UILabel) {
        guard let portfolio, let index else {
            comparing.text = "—"
            over.text = ""
            return
        }
        let difference = Self.rounded(portfolio) - Self.rounded(index)
        let roundedDifference = Self.rounded(difference)
        let color: UIColor?
        if roundedDifference > 0 {
            over.text = "Overperforming the"
            color = UIColor(named: "uptrend")
        } else if roundedDifference < 0 {
            over.text = "Underperforming the"
            color = UIColor(named: "downtrend")
        } else {
            over.text = "Level with the"
            color = .secondaryLabel
        }
        over.textColor = color
        comparing.textColor = color
        comparing.text = Self.percentText(roundedDifference)
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    ///"+0.45%", "-1.20%", "0.00%".
    private static func percentText(_ value: Double) -> String {
        let value = rounded(value)
        return (value > 0 ? "+" : "") + String(format: "%.2f%%", value)
    }

    ///One line on the shared clock: its value at each moment it has a bar for or has already
    ///started, carried forward across a missing bar, and nothing before its first bar or after
    ///its last (NaN, which the chart leaves out).
    private static func line(_ bars: [MarketsClosedPrices]?, on timeline: [Double]) -> [Double] {
        guard let bars, let first = bars.first?.timeStamp, let last = bars.last?.timeStamp else { return [] }
        var next = 0
        var current = Double.nan
        return timeline.map { time in
            while next < bars.count, bars[next].timeStamp <= time {
                current = bars[next].close
                next += 1
            }
            return time < first || time > last ? .nan : current
        }
    }

    ///The watchlist's average at each moment. A stock that has no bar at a moment counts with
    ///its last value, so the average doesn't jump when one stock skips a bar; a stock that hasn't
    ///started yet is left out of that moment. The last moment uses every stock's latest value,
    ///even one whose bar came after the indexes' last (a coin, or a quote the server stood in
    ///with), so the line ends exactly on the headline number.
    private static func averageLine(_ stocks: [[MarketsClosedPrices]], on timeline: [Double]) -> [Double] {
        guard !stocks.isEmpty else { return [] }
        var nextIndex = Array(repeating: 0, count: stocks.count)
        var latest: [Double?] = Array(repeating: nil, count: stocks.count)
        let lastTime = timeline.last
        return timeline.map { time in
            if time == lastTime {
                let finals = stocks.compactMap { $0.last?.close }
                return finals.isEmpty ? .nan : finals.reduce(0, +) / Double(finals.count)
            }
            for (stock, bars) in stocks.enumerated() {
                while nextIndex[stock] < bars.count, bars[nextIndex[stock]].timeStamp <= time {
                    latest[stock] = bars[nextIndex[stock]].close
                    nextIndex[stock] += 1
                }
            }
            let known = latest.compactMap { $0 }
            return known.isEmpty ? .nan : known.reduce(0, +) / Double(known.count)
        }
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
