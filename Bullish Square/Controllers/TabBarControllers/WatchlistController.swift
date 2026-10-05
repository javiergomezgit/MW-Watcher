//
//  MyTickersController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import Foundation
import LocalAuthentication
import AMPopTip

class WatchlistController: UIViewController {
    
    //MARK: Variables
    var tickersFeatures: [TickersFeatures] = []
    //Keyed by ticker. The API can return fewer entries than the saved watchlist, or in a
    //different order, so a price must never be located by row index.
    var tickersValues: [String: TickersCurrentValues] = [:]
    ///When each ticker's price was last asked for. Per ticker rather than one timestamp for
    ///the screen, so that adding a stock or switching watchlists still fetches the tickers
    ///that are new while skipping the ones already on hand.
    private var priceFetchedAt: [String: Date] = [:]
    ///Prices asked for more recently than this are reused instead of requested again.
    ///Short enough that the watchlist still reads as live, long enough to absorb tab switches,
    ///returning from a chart and flipping between watchlists. Pull to refresh ignores it.
    private let priceFreshness: TimeInterval = 60

    ///Tickers waiting for their analyst consensus, asked for one at a time.
    private var analystTargetQueue: [String] = []
    ///The one being asked for right now. It has already left the queue, so without this a
    ///watchlist appearing mid-request queued it a second time.
    private var analystTargetInFlight: String?
    ///A failed ticker is left alone for a few minutes. Without this, every tab switch while the
    ///server is down would ask again for every stock on the list.
    private var analystTargetRetryAfter: [String: Date] = [:]
    private let analystTargetRetryDelay: TimeInterval = 5 * 60
    ///Five-minute bars across today's session, about 79 points, which is what the sparkline
    ///draws. The previous close and the latest price come back identical to the old one-bar
    ///"interval=1d", so every number on screen is unchanged; only the line is new.
    var timeRange: String = "&interval=5m&range=1d"
    let savedTickers = SaveTickers()
    var refreshControl = UIRefreshControl()
    var alreadyLaunched = false
    var percentageChg = 0.0
    var loadStocks = false //Implemented when the updating for the new version 2.0.0, old database had different information. Temporal until everyone is on version 2.0.0 and more
//    var spinner = UIActivityIndicatorView(style: .large)
    private let imageViewTopRightButton = UIImageView(image: UIImage(named: "plus.square.on.square"))
    
    ///Sits where the simulated-portfolio icon used to be. The portfolio moved to the floating
    ///button so this slot could carry the watchlist switcher.
    private let imageViewManageWatchlistsButton: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "rectangle.stack", withConfiguration: configuration))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    ///Floating action button, bottom right, for the simulated portfolio. The plain symbol
    ///rather than the .circle variant, which would draw a circle inside a circular button.
    private let simulatedPortfolioButton: UIButton = {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        button.setImage(UIImage(systemName: "chart.line.uptrend.xyaxis", withConfiguration: configuration), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(named: "colorAccent")
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    //MARK: Outlets and IBActions
    @IBOutlet var tableView: UITableView!
    
    //MARK: Initials
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUITopRightButton()
        setupSimulatedPortfolioButton()
        
        WatchlistStore.shared.ensureDefaultExists()
        refreshWatchlistTitle()
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingWatchlist")
        UserDefaults.standard.set(true, forKey: "firstLaunchingWatchlist")
        UserDefaults.standard.synchronize()
        
        //change to true for testing
        if !isFirstLaunch {
            alreadyLaunched = false
        } else {
            alreadyLaunched = true
        }
        
        //        let font = UIFont.boldSystemFont(ofSize: 16)
        //        let titleTextAttributes: [NSAttributedString.Key: Any] = [
        //            .font: font,
        //            .foregroundColor: UIColor.white,
        //        ]
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading...")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        //Assigned rather than added as a subview. This is a plain UIViewController with a
        //table view outlet, so UIKit only manages the control - and resets the content inset
        //on endRefreshing - when it owns it. Added as a bare subview the control stayed
        //stuck at its expanded offset.
        tableView.refreshControl = refreshControl
        
        startStopSpinner(start: true)
        
        loadInitialStocks()
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
    
    func loadInitialStocks(){
        if !self.alreadyLaunched {
            self.showFirstTimeNotification(whereView: self.imageViewTopRightButton)
        }
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let appversionCharacter = appVersion.first!
        
        
//        if appversionCharacter.wholeNumberValue! >= 2 {
//            loadStocks = true
//            let loadSavedTickers = self.savedTickers.loadTickers()
//            if !loadSavedTickers.isEmpty {
//                self.loadMultipleStocks(savedTickers: loadSavedTickers)
//            } else {
//                self.startStopSpinner(start: false)
//            }
//        } else {
//            loadStocks = false
////            savedTickers.deleteAllTickers()
//            startStopSpinner(start: false)
//
//            
////             Create the alert controller
//            let alertController = UIAlertController(title: "Reinstall", message: "Uninstall App and download again!", preferredStyle: .alert)
//            
//            // Create the actions
//            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
//                UIAlertAction in
//                exit(0)
//            }
//            
//            // Add the actions
//            alertController.addAction(okAction)
//            
//            // Present the controller
//            self.present(alertController, animated: true, completion: nil)
//            
//            
//        }
        
    }
    
    func addingTicker() {
        
        let vc = SearchStocksController()
        vc.delegate = self
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        refreshStartedAt = Date()
        let loadSavedTickers = savedTickers.loadTickers()
        loadMultipleStocks(savedTickers: loadSavedTickers, force: true)
    }
    
    func showFirstTimeNotification(whereView: UIView) {
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX - 70, y: whereView.frame.minY - 30, width: 100, height: 100)
        popTip.show(text: "Add your favorite stocks", direction: .left, maxWidth: 100, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
    }
    
    func showNotificationOldVersionApp(whereView: UIView) {
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX - 70, y: whereView.frame.minY - 30, width: 100, height: 100)
        popTip.show(text: "Uninstall App and Update it", direction: .left, maxWidth: 100, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
    }
    
    ///When the current pull-to-refresh began, so the control is not closed mid-open.
    private var refreshStartedAt: Date?
    
    ///Shortest time the refresh control stays up. UIRefreshControl ignores endRefreshing()
    ///while its opening animation is still running, and an instant failure - airplane mode
    ///returns in milliseconds, with no network round trip - lands inside that window every
    ///time. The control then never returns to rest: the table stays pulled down and the
    ///"Loading..." title stays on screen. A successful load takes long enough to miss it.
    private let minimumRefreshDuration: TimeInterval = 0.6
    
    ///Every exit from a load goes through here. The refresh control and the spinner used to
    ///be cleared separately, and the failure branch cleared only one of them.
    private func finishLoading() {
        startStopSpinner(start: false)
        
        guard refreshControl.isRefreshing else {
            refreshStartedAt = nil
            return
        }
        
        let elapsed = refreshStartedAt.map { Date().timeIntervalSince($0) } ?? minimumRefreshDuration
        let remaining = max(0, minimumRefreshDuration - elapsed)
        refreshStartedAt = nil
        
        guard remaining > 0 else {
            refreshControl.endRefreshing()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }
    
    ///`force` is for pull to refresh, where the user has asked for new prices outright.
    func loadMultipleStocks(savedTickers: [TickersFeatures], force: Bool = false) {
        //An empty watchlist was sent to the price API as an empty symbol list, which comes
        //back as invalidJSON. Pull-to-refresh does not guard for empty the way viewWillAppear
        //does, so refreshing an empty watchlist span "Loading..." forever.
        guard !savedTickers.isEmpty else {
            tickersFeatures = []
            tickersValues = [:]
            priceFetchedAt = [:]
            tableView.reloadData()
            finishLoading()
            return
        }
        
        //Show the new rows straight away. tickersFeatures used to be assigned only in the
        //success branch, so switching watchlists left the previous list on screen until
        //prices came back and it read as the switch not having worked. tickersValues is keyed
        //by ticker, so anything the two lists share keeps its price and the rest fill in.
        tickersFeatures = savedTickers
        tableView.reloadData()
        
        var mergedTickers = ""
        
        loadPendingLogos(for: savedTickers)
        loadPendingAnalystTargets(for: savedTickers)

        //This ran on every appearance: each tab switch and each return from a chart was a full
        //price request straight into the API quota, and that endpoint already answers with
        //invalidJSON under load. The rows above come from Core Data regardless, so skipping
        //the request changes nothing on screen when the prices are recent.
        guard force || !pricesAreFresh(for: savedTickers) else {
            finishLoading()
            return
        }
        
        //Captured before the request: the list on screen can change while it is in flight.
        let requestedTickers = savedTickers.map(\.ticker)
        
        for (index, savedTicker) in savedTickers.enumerated() {
            let ticker = savedTicker.ticker
            if index == 0 {
                mergedTickers = ticker
            } else {
                mergedTickers = mergedTickers + "," + ticker
            }
        }
        
        StockAPI.shared.getPriceMultipleStocks(tickersGroup: mergedTickers, timeRange: timeRange) { result in
            
            print (mergedTickers)
            switch result {
                
            case .success(let tickersGroupPrices):
                
                DispatchQueue.main.async {
                    //Assigned on main: the table view reads both of these while scrolling, and
                    //they were previously replaced from a URLSession queue.
                    self.tickersFeatures = savedTickers
                    self.recordPrices(tickersGroupPrices, for: requestedTickers)
                    
                    self.tableView.reloadData()
                    self.finishLoading()
                }
                
            case .failure(let error):
                print (error)
                DispatchQueue.main.async {
                    //Ends first. Dismissing a refresh control while a modal is being
                    //presented over the scroll view drops its animation and leaves it
                    //spinning, which is why only the failure path stuck.
                    self.finishLoading()
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                }
            }
        }
    }
    
    ///True only when every ticker on screen had its price asked for within `priceFreshness`.
    ///A ticker never asked about - just added, or new to this watchlist - makes it false.
    private func pricesAreFresh(for tickers: [TickersFeatures], now: Date = Date()) -> Bool {
        tickers.allSatisfy { ticker in
            guard let fetchedAt = priceFetchedAt[ticker.ticker] else { return false }
            return now.timeIntervalSince(fetchedAt) < priceFreshness
        }
    }
    
    ///Merges a response into the prices already held rather than replacing them, so a
    ///watchlist switched away from keeps its prices for when it comes back.
    ///
    ///Every requested ticker is stamped, including any the API left out. Some tickers are
    ///never returned, and without the stamp they would force a request for the whole list on
    ///every appearance. Leaving them out also clears any old price, so a ticker the API
    ///stopped answering for shows the placeholder rather than a stale number.
    private func recordPrices(_ prices: [TickersCurrentValues], for requestedTickers: [String], at now: Date = Date()) {
        let received = Dictionary(prices.map { ($0.ticker, $0) }, uniquingKeysWith: { first, _ in first })
        for ticker in requestedTickers {
            tickersValues[ticker] = received[ticker]
            priceFetchedAt[ticker] = now
        }
    }
    
    ///Fetches missing logos one at a time. Firing one request per new ticker simultaneously
    ///starved the URLSession queue and some logos silently ended up as the placeholder.
    ///Empty imageTickerName marks "not fetched yet"; "mw-logo" is the legacy sentinel that
    ///older installs still have stored, so it is honoured for migration.
    private func loadPendingLogos(for savedTickers: [TickersFeatures]) {
        var pending = savedTickers.filter {
            $0.imageTickerName.isEmpty || $0.imageTickerName == "mw-logo"
        }
        
        func fetchNext() {
            guard !pending.isEmpty else { return }
            let next = pending.removeFirst()
            loadImageStock(individualTicker: next.ticker, nameTicker: next.nameTicker) {
                fetchNext()
            }
        }
        fetchNext()
    }
    
    func loadImageStock(individualTicker: String, nameTicker: String, completion: @escaping () -> Void = {}) {
        
        StockAPI.shared.getLogoStock(ticker: individualTicker) { result in
            switch result {
            case .success(let imageCompany):
                
                //Update in place. The old delete-then-insert deleted every row still holding
                //the placeholder logo, so adding several stocks at once lost most of them.
                self.savedTickers.updateTickerLogo(ticker: individualTicker, image: imageCompany, imageName: individualTicker)
                
            case .failure(let error):
                
                if let apiError = error as? StockAPI.APIError, case .logoUnavailable = apiError {
                    //No logo exists for this symbol, so record a letter avatar and stop asking.
                    let avatar = UIImage.letterAvatar(for: individualTicker)
                    self.savedTickers.updateTickerLogo(ticker: individualTicker, image: avatar, imageName: individualTicker)
                } else {
                    //Transient. Leave the row unresolved so the next appearance retries it,
                    //rather than recording the placeholder as if it were the real logo.
                    print("Logo fetch failed for \(individualTicker), will retry: \(error)")
                }
                
            }
            completion()
        }
    }

    // MARK: - Analyst targets

    ///Queues the tickers on this list whose consensus is missing or more than a day old, and
    ///works through them one at a time like the logos, so a long list never bursts into the
    ///server's rate limit. Only the list on screen is fetched.
    ///
    ///Decoration only: a failure leaves the line empty and never raises an alert.
    private func loadPendingAnalystTargets(for savedTickers: [TickersFeatures], now: Date = Date()) {
        let store = AnalystTargetStore.shared
        for ticker in savedTickers.map(\.ticker) where !ticker.isEmpty {
            guard store.needsFetch(ticker, now: now),
                  ticker != analystTargetInFlight,
                  !analystTargetQueue.contains(ticker),
                  analystTargetRetryAfter[ticker].map({ now >= $0 }) ?? true else { continue }
            analystTargetQueue.append(ticker)
        }
        fetchNextAnalystTarget()
    }

    private func fetchNextAnalystTarget() {
        guard analystTargetInFlight == nil else { return }
        //Something queued a while ago may have been answered since, so check again here.
        while let next = analystTargetQueue.first, !AnalystTargetStore.shared.needsFetch(next) {
            analystTargetQueue.removeFirst()
        }
        guard !analystTargetQueue.isEmpty else { return }
        let ticker = analystTargetQueue.removeFirst()
        analystTargetInFlight = ticker

        StockAPI.shared.getAnalystTarget(ticker: ticker) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let target):
                    AnalystTargetStore.shared.record(target, for: ticker)
                    self.analystTargetRetryAfter.removeValue(forKey: ticker)
                    self.reloadRow(forTicker: ticker)
                case .failure(let error):
                    print("Analyst target for \(ticker) failed, will retry later: \(error)")
                    self.analystTargetRetryAfter[ticker] = Date().addingTimeInterval(self.analystTargetRetryDelay)
                }
                self.analystTargetInFlight = nil
                self.fetchNextAnalystTarget()
            }
        }
    }

    ///Found by ticker at the moment the answer arrives, not by a row captured before the
    ///request: the list may have been switched or edited while it was in flight.
    private func reloadRow(forTicker ticker: String) {
        guard let row = tickersFeatures.firstIndex(where: { $0.ticker == ticker }) else { return }
        let indexPath = IndexPath(row: row, section: 0)
        guard tableView.indexPathsForVisibleRows?.contains(indexPath) == true else { return }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    ///"$328 · -0.4% · Buy" beside a target glyph, which says "target" without the word. The upside uses the price shown on the same row, never the
    ///one inside the analyst data, so a row cannot show two different prices. Without a price
    ///yet the percentage is left out rather than guessed.
    private func analystTargetLine(for ticker: String) -> String? {
        guard let target = AnalystTargetStore.shared.entry(for: ticker)?.target else { return nil }

        var parts = [AnalystTargetFormat.price(target.meanTarget)]
        if let price = tickersValues[ticker]?.marketPrice,
           let upside = target.upsidePercent(from: price) {
            parts.append(AnalystTargetFormat.percent(upside))
        }
        if let consensus = target.consensusLabel {
            parts.append(consensus)
        }
        return parts.joined(separator: " · ")
    }

    @objc func openAnalystTarget(sender: UIButton) {
        //Resolved at tap time, like openChart, so a delete above this row cannot redirect it.
        let buttonCentre = CGPoint(x: sender.bounds.midX, y: sender.bounds.midY)
        guard let indexPath = tableView.indexPathForRow(at: sender.convert(buttonCentre, to: tableView)),
              indexPath.row < tickersFeatures.count else { return }

        let tickerFeatures = tickersFeatures[indexPath.row]
        //The line is only visible with a target on hand, but the store is the authority.
        guard let entry = AnalystTargetStore.shared.entry(for: tickerFeatures.ticker),
              let target = entry.target else { return }

        let price = tickersValues[tickerFeatures.ticker]?.marketPrice
        let detail = AnalystTargetController(ticker: tickerFeatures.ticker,
                                             companyName: tickerFeatures.nameTicker,
                                             currentPrice: (price ?? 0) > 0 ? price : nil,
                                             target: target,
                                             fetchedAt: entry.fetchedAt)
        let navigationController = UINavigationController(rootViewController: detail)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

}

extension WatchlistController: SearchStocksControllerDelegate {
    func searchStocksControllerDidDismiss(_ controller: SearchStocksController) {
        let loadSavedTickers = savedTickers.loadTickers()
        loadMultipleStocks(savedTickers: loadSavedTickers)
    }
}

//Customs
//Delegate for table view
extension WatchlistController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickersFeatures.count
    }

    ///Overrides the storyboard's 75pt to make room for the analyst line. The same for every
    ///row, with or without a target, so rows never jump as targets arrive.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return WatchlistViewCell.rowHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "myTickersCell", for: indexPath) as! WatchlistViewCell
                
        cell.tickerLabel.text = " "
        cell.currentPriceLabel.text = "—"
        cell.nameCompanyLabel.text = " "

        //A cell reused for a ticker whose price has not arrived must not keep the previous
        //stock's change and up/down colour, which is most visible after switching watchlists.
        cell.showChange(percent: nil)
        cell.sparklineView.reset()
        
        let tickerFeatures = tickersFeatures[indexPath.row]
        let ticker = tickerFeatures.ticker
        if ticker != "" {
            
            //Identity comes from Core Data, so it is always present
            cell.tickerLabel.text = ticker
            cell.imageCompanyImageView.image = tickerFeatures.imageTicker
            cell.nameCompanyLabel.text = tickerFeatures.nameTicker
            
            //UIControl keeps duplicate registrations, so a reused cell fired this action once
            //per dequeue. Removing the pair first guarantees exactly one.
            cell.openChartButton.removeTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
            cell.openChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
            cell.analystTargetButton.removeTarget(self, action: #selector(openAnalystTarget(sender:)), for: .touchUpInside)
            cell.analystTargetButton.addTarget(self, action: #selector(openAnalystTarget(sender:)), for: .touchUpInside)

            //Before the price guard: a target already known still shows while prices load,
            //just without the percentage.
            cell.showAnalystTarget(analystTargetLine(for: ticker),
                                   recommendationKey: AnalystTargetStore.shared.entry(for: ticker)?.target?.consensusKey)

            //Prices come from the API, which may not have returned this ticker at all.
            //Leave the placeholder values in place rather than showing another stock's price.
            guard let values = tickersValues[ticker] else { return cell }
            
            if values.marketPrice != 0.0  {
                cell.currentPriceLabel.text = Self.priceText(values.marketPrice)
            }

            let percentage = Double(round(100*values.changePercent)/100)
            cell.showChange(percent: percentage)

            //The same "percentage < 0" test as the change pill, so the line can never be
            //green on a red row.
            cell.sparklineView.configure(closes: values.intradayCloses,
                                         previousClose: values.previousPrice,
                                         isUp: !(percentage < 0))
        }
        
        return cell
    }
    
    ///"$1,234.56": thousands grouped with commas, always two decimals. Fixed to en_US so the
    ///row reads the same on a phone set to a comma-decimal region, like the rest of the app's
    ///dollar figures.
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    ///Coins under a dollar (SHIB, DOGE) keep their digits; two decimals would show $0.00.
    private static let smallPriceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    private static func priceText(_ value: Double) -> String {
        let formatter = abs(value) < 1 ? smallPriceFormatter : priceFormatter
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    @objc func openChart(sender: UIButton) {
        //Resolved at tap time from where the button actually sits. It previously used a tag
        //stamped in cellForRowAt, and deleting a row does not re-dequeue the rows below it, so
        //their tags still pointed at pre-delete positions and opened a different stock.
        let buttonCentre = CGPoint(x: sender.bounds.midX, y: sender.bounds.midY)
        guard let indexPath = tableView.indexPathForRow(at: sender.convert(buttonCentre, to: tableView)),
              indexPath.row < tickersFeatures.count else { return }
        
        let tickerFeatures = tickersFeatures[indexPath.row]
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else {
            print("Failed to instantiate ChartController")
            return
        }
        
        //Open the chart even when no price came back; it loads its own series from the ticker
        let tickerCurrentValues = tickersValues[tickerFeatures.ticker]
            ?? TickersCurrentValues(ticker: tickerFeatures.ticker, marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
        
        destination.informationStockTicker = tickerCurrentValues
        destination.nameTicker = tickerFeatures.nameTicker
        destination.imageCompany = tickerFeatures.imageTicker
        destination.modalTransitionStyle = .crossDissolve
//        self.present(destination!, animated: true, completion: nil)
        self.navigationController?.pushViewController(destination, animated: true)
        
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let tickerFeatures = tickersFeatures[indexPath.row]
            savedTickers.deleteTicker(ticker: tickerFeatures.ticker)
            
            //Dropped together. A fetch time left without its price would read as fresh and
            //show the placeholder if the ticker were added straight back.
            tickersValues.removeValue(forKey: tickerFeatures.ticker)
            priceFetchedAt.removeValue(forKey: tickerFeatures.ticker)
            tickersFeatures.remove(at: indexPath.row)
            
            tableView.deleteRows(at: [indexPath], with: .left)
        }
    }
}

//Delegate for keyboard
extension WatchlistController {
    func initializeHideKeyboard(){
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissMyKeyboard))
        view.addGestureRecognizer(tap)
    }
    @objc func dismissMyKeyboard(){
        view.endEditing(true)
    }
}



//MARK: Right top button in navigation controller
extension WatchlistController {
    private struct ConstTopRightButton {
        /// Image height/width for Large NavBar state
        static let ImageSizeForLargeState: CGFloat = 36
        /// Margin from right anchor of safe area to right anchor of Image
        static let ImageRightMargin: CGFloat = 18
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Large NavBar state
        static let ImageBottomMarginForLargeState: CGFloat = 14
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Small NavBar state
        static let ImageBottomMarginForSmallState: CGFloat = 5
        /// Image height/width for Small NavBar state
        static let ImageSizeForSmallState: CGFloat = 28
        /// Height of NavBar for Small state. Usually it's just 44
        static let NavBarHeightSmallState: CGFloat = 44
        /// Height of NavBar for Large state. Usually it's just 96.5 but if you have a custom font for the title, please make sure to edit this value since it changes the height for Large state of NavBar
        static let NavBarHeightLargeState: CGFloat = 96.5
    }
    
    private func setupUITopRightButton() {
        //        navigationController?.navigationBar.prefersLargeTitles = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(addingTicketTapped(tapGestureRecognizer:)))
        imageViewTopRightButton.isUserInteractionEnabled = true
        imageViewTopRightButton.tintColor = UIColor(named: "colorSecondary")
        imageViewTopRightButton.addGestureRecognizer(tapGestureRecognizer)
        
        let tapGestureRecognizerManage = UITapGestureRecognizer(target: self, action: #selector(manageWatchlistsTapped(tapGestureRecognizer:)))
        imageViewManageWatchlistsButton.isUserInteractionEnabled = true
        imageViewManageWatchlistsButton.tintColor = UIColor(named: "colorSecondary")
        imageViewManageWatchlistsButton.addGestureRecognizer(tapGestureRecognizerManage)
        
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewTopRightButton)
        navigationBar.addSubview(imageViewManageWatchlistsButton)
        imageViewManageWatchlistsButton.translatesAutoresizingMaskIntoConstraints = false
        imageViewTopRightButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageViewTopRightButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -ConstTopRightButton.ImageRightMargin),
            imageViewTopRightButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -ConstTopRightButton.ImageBottomMarginForLargeState),
            imageViewTopRightButton.heightAnchor.constraint(equalToConstant: ConstTopRightButton.ImageSizeForLargeState),
            imageViewTopRightButton.widthAnchor.constraint(equalTo: imageViewTopRightButton.heightAnchor),
            imageViewManageWatchlistsButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(imageViewTopRightButton.frame.width*2.9)),
            imageViewManageWatchlistsButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -ConstTopRightButton.ImageBottomMarginForLargeState),
            imageViewManageWatchlistsButton.heightAnchor.constraint(equalToConstant: ConstTopRightButton.ImageSizeForLargeState),
            imageViewManageWatchlistsButton.widthAnchor.constraint(equalTo: imageViewTopRightButton.heightAnchor)
        ])
    }
    
    ///On the view rather than the navigation bar, so it stays put while the table scrolls.
    ///The safe area bottom already accounts for the tab bar.
    private func setupSimulatedPortfolioButton() {
        view.addSubview(simulatedPortfolioButton)
        view.bringSubviewToFront(simulatedPortfolioButton)
        simulatedPortfolioButton.addTarget(self, action: #selector(simulatedPortfolioButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            simulatedPortfolioButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            simulatedPortfolioButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            simulatedPortfolioButton.widthAnchor.constraint(equalToConstant: 56),
            simulatedPortfolioButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        //The button floats over the table, so without room below the last row it covered
        //that row's price and change with no way to scroll them clear.
        let clearance: CGFloat = 56 + 20 + 8
        tableView.contentInset.bottom = clearance
        tableView.verticalScrollIndicatorInsets.bottom = clearance
    }
    
    @objc private func simulatedPortfolioButtonTapped() {
        openSimulatedPortfolio()
    }
    
    @objc func manageWatchlistsTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let manageController = ManageWatchlistsController()
        manageController.delegate = self
        
        let navigationController = UINavigationController(rootViewController: manageController)
        //A sheet rather than a full screen: the list underneath stays visible, so switching
        //reads as changing what is shown rather than navigating somewhere else.
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }
    
    ///The navigation title is the active watchlist's name, which is how you know which list
    ///is showing now that there is more than one.
    private func refreshWatchlistTitle() {
        title = WatchlistStore.shared.activeWatchlistName
    }
    
    private func openSimulatedPortfolio() {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "simulatedPortfolio") //as? UIViewController
        
        destination.modalTransitionStyle = .coverVertical//.crossDissolve
        destination.modalPresentationStyle = .fullScreen
        self.show(destination, sender: self)
    }
    
    @objc func addingTicketTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        addingTicker()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let loadSavedTickers = savedTickers.loadTickers()
        loadMultipleStocks(savedTickers: loadSavedTickers)
    }
    
    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageViewTopRightButton.alpha = show ? 1.0 : 0.0
            self.imageViewManageWatchlistsButton.alpha = show ? 1.0 : 0.0
        }
    }
}

// MARK: - ManageWatchlistsControllerDelegate

extension WatchlistController: ManageWatchlistsControllerDelegate {
    
    func manageWatchlistsControllerDidChangeSelection(_ controller: ManageWatchlistsController) {
        refreshWatchlistTitle()
        //Reload from the store rather than reusing what is on screen: the rows belong to the
        //list that was showing a moment ago.
        loadMultipleStocks(savedTickers: savedTickers.loadTickers())
    }
}
