//
//  SearchStockController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

protocol SearchStocksControllerDelegate: AnyObject {
    func searchStocksControllerDidDismiss(_ controller: SearchStocksController)
}

class SearchStocksController: UIViewController, SearchStocksViewCellDelegate {
    
    weak var delegate: SearchStocksControllerDelegate?

    private var stocks = [Stock]()
    private var filteredStocks = [Stock]()
    private var watchlist: Set<String> = [] // Tracks added tickers for isAdded state
    private var searchTimer: Timer? // Debounce timer — prevents API call on every keystroke
    ///Answers already received this session, by search text, including searches that
    ///matched nothing. Typing "A", "AP", back to "A" asked the API three times.
    private var resultsByQuery: [String: [Stock]] = [:]
    ///Short enough to feel immediate, long enough that a quick typist does not send a request
    ///per letter. Was 0.4 s.
    private let typingPause: TimeInterval = 0.25
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for stocks"
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(SearchStocksViewCell.self, forCellReuseIdentifier: SearchStocksViewCell.identifier)
        table.backgroundColor = UIColor(named: "colorPrimary")
        return table
    }()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        tableView.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(didTapDismiss))
        searchBar.becomeFirstResponder()
        searchBar.autocapitalizationType = .allCharacters
        definesPresentationContext = true
        
        loadWatchlist()
    }
    
    // Dismisses the search screen and notifies the parent
    @objc private func didTapDismiss() {
        delegate?.searchStocksControllerDidDismiss(self)
        dismiss(animated: true, completion: nil)
    }
    
    // Loads saved tickers into the watchlist set so isAdded state is correct on first render
    private func loadWatchlist() {
        let loadSavedTickers = SaveTickers().loadTickers()
        for loadSavedTicker in loadSavedTickers {
            watchlist.insert(loadSavedTicker.ticker)
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    ///Asks the API, remembers the answer, and shows it only if it is still what the search
    ///bar says. Answers used to be shown in arrival order, so a slow "A" could replace the
    ///results for "AP" typed after it.
    private func searchStocks(query: String) {
        StockAPI.shared.searchStocks(ticker: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let stocks):
                    self.resultsByQuery[query] = stocks
                    guard query == Self.normalized(self.searchBar.text) else { return }
                    //An empty answer shows an empty list. It used to be ignored, leaving the
                    //previous search's stocks on screen under the new text.
                    self.show(stocks)
                case .failure(let error):
                    //Not remembered, so typing it again retries. What is on screen stays.
                    print("Stock search for \(query) failed: \(error)")
                }
            }
        }
    }
    
    // Uses reloadSections instead of reloadData to force full cell reconfiguration,
    // preventing stale ticker values from carrying over between searches.
    // Re-stamps cell tags after reload so didTapAddButton can look up the correct row.
    private func show(_ results: [Stock]) {
        stocks = results
        display(results)
    }
    
    ///Draws a list without replacing `stocks`, the full answer that narrowing works from.
    private func display(_ list: [Stock]) {
        filteredStocks = list
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        
        // Re-stamp tags on all visible cells — tags go stale when list size changes,
        // causing didTapAddButton to look up the wrong row or go out of range
        for cell in tableView.visibleCells {
            if let indexPath = tableView.indexPath(for: cell) {
                cell.tag = indexPath.row
            }
        }
    }
    
    ///Search text as it is sent and remembered: trimmed and upper-cased, so "aapl " and
    ///"AAPL" are one search.
    private static func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
    
    ///While the request for a longer search runs, narrow what is already on screen: "AP"
    ///after "A" keeps the "A" results starting with AP or naming it, straight away.
    private static func narrowed(_ results: [Stock], to query: String) -> [Stock] {
        results.filter {
            $0.ticker.uppercased().hasPrefix(query) || $0.nameTicker.uppercased().contains(query)
        }
    }
    
    let child = Spinner()
    
    // Shows or hides the loading spinner overlay
    func startStopSpinner(start: Bool) {
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
}

// MARK: - TableView DataSource & Delegate
extension SearchStocksController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredStocks.count
    }
    
    // Configures each cell with stock data, isAdded state from watchlist, and a tag
    // matching its row index so didTapAddButton can resolve the correct stock
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchStocksViewCell.identifier, for: indexPath) as! SearchStocksViewCell
        guard indexPath.row < filteredStocks.count else { return cell }
        
        let ticker = filteredStocks[indexPath.row]
        let isAdded = watchlist.contains(ticker.ticker)
        
        cell.configure(ticker: ticker.ticker, name: ticker.nameTicker, exchange: ticker.exchange, isAdded: isAdded)
        cell.tag = indexPath.row // Used in didTapAddButton to resolve correct stock by position
        cell.delegate = self
        
        return cell
    }
    
    // Handles add/remove tap from a search result cell.
    // Uses cell.tag instead of the ticker string to avoid stale cell state issues.
    // Updates the cell appearance immediately, then reloads the row to sync state.
    func didTapAddButton(in cell: SearchStocksViewCell, isAdded: Bool, ticker: String) {
        let row = cell.tag
        guard row < filteredStocks.count else { return } // Guard against stale tag after list change
        
        let stock = filteredStocks[row]
        
        if !isAdded {
            saveIndividualStock(individualTicker: stock.ticker, nameTicker: stock.nameTicker)
        } else {
            deleteIndividualStock(individualTicker: stock.ticker, nameTicker: stock.nameTicker)
        }
        
        // Update cell appearance immediately without waiting for reloadRows
        cell.configure(ticker: stock.ticker, name: stock.nameTicker, exchange: stock.exchange, isAdded: !isAdded)
        cell.tag = row // Re-stamp tag since configure doesn't set it
        
        tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
    }
    
    // Removes stock from watchlist and Core Data
    func deleteIndividualStock(individualTicker: String, nameTicker: String) {
        self.watchlist.remove(individualTicker)
        SaveTickers().deleteTicker(ticker: individualTicker)
    }
    
    // Saves stock to watchlist and Core Data
    func saveIndividualStock(individualTicker: String, nameTicker: String) {
        //imageTickerName is left empty to mark "logo not fetched yet". It must never carry a
        //sentinel value, because delete predicates used to match on this field.
        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: UIImage(named: "mw-logo")!, imageTickerName: "")
        self.watchlist.insert(individualTicker)
        SaveTickers().saveTicker(tickerFeatures: tickerFeatures)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        searchBar.resignFirstResponder()
        tableView.deselectRow(at: indexPath, animated: true)
        openChart(index: indexPath.row)
    }
    
    // Fetches price and logo for selected stock then pushes ChartController
    @objc func openChart(index: Int) {
        //Read out of filteredStocks once. The searches below are asynchronous and the user
        //can keep typing, so index is not safe to hold on to until they come back.
        let individualTicker = filteredStocks[index].ticker
        let nameTicker = filteredStocks[index].nameTicker

        //Opens straight away. This used to wait for the price and then the logo before
        //pushing, and the chart then fetched its history, so the tap took three round trips.
        //The chart now loads all three itself, the price and logo alongside the history.
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else { return }

        destination.informationStockTicker = TickersCurrentValues(ticker: individualTicker, marketPrice: 0.0, previousPrice: 0.0, changePercent: 0.0)
        destination.nameTicker = nameTicker
        destination.imageCompany = UIImage(named: "mw-logo")
        destination.loadsQuoteAndLogo = true
        destination.modalTransitionStyle = .crossDissolve
        navigationController?.pushViewController(destination, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - SearchBar Delegate
extension SearchStocksController: UISearchBarDelegate {
    
    // Debounce search input — waits 0.4s after user stops typing before firing API call.
    // Prevents rapid successive calls on every keystroke. Clears results if search is empty.
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        let query = Self.normalized(searchText)
        
        guard !query.isEmpty else {
            show([])
            return
        }
        
        //Searched before this session: shown at once, no request.
        if let remembered = resultsByQuery[query] {
            show(remembered)
            return
        }
        
        //Something to look at while the API answers, when the results on hand cover it.
        let narrowedNow = Self.narrowed(stocks, to: query)
        if !narrowedNow.isEmpty {
            display(narrowedNow)
        }
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: typingPause, repeats: false) { [weak self] _ in
            self?.searchStocks(query: query)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchTimer?.invalidate()
        show([])
    }
}
