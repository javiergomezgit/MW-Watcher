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
    var timeRange: String = "&interval=1d&range=1d"
    private var searchTimer: Timer? // Debounce timer — prevents API call on every keystroke
    
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
    
    // Fetches matching stocks from API and reloads the table.
    // Uses reloadSections instead of reloadData to force full cell reconfiguration,
    // preventing stale ticker values from carrying over between searches.
    // Re-stamps cell tags after reload so didTapAddButton can look up the correct row.
    private func searchStocks(ticker: String) {
        StockAPI.shared.searchStocks(ticker: ticker) { stocks, error in
            guard let stocks = stocks, !stocks.isEmpty else {
                print(error as Any)
                return
            }
            DispatchQueue.main.async {
                self.stocks = stocks
                self.filteredStocks = stocks
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
                
                // Re-stamp tags on all visible cells — tags go stale when list size changes,
                // causing didTapAddButton to look up the wrong row or go out of range
                for cell in self.tableView.visibleCells {
                    if let indexPath = self.tableView.indexPath(for: cell) {
                        cell.tag = indexPath.row
                    }
                }
            }
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
        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: UIImage(named: "mw-logo")!, imageTickerName: "mw-logo")
        self.watchlist.remove(individualTicker)
        SaveTickers().deleteTicker(tickerFeatures: tickerFeatures)
    }
    
    // Saves stock to watchlist and Core Data
    func saveIndividualStock(individualTicker: String, nameTicker: String) {
        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: UIImage(named: "mw-logo")!, imageTickerName: "mw-logo")
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
        let individualTicker = filteredStocks[index].ticker
        let nameTicker = filteredStocks[index].nameTicker
        
        self.startStopSpinner(start: true)
        
        StockAPI.shared.getPriceSingleTicker(ticker: individualTicker, timeRange: self.timeRange) { result in
            switch result {
            case .success(let tickerCurrentValues):
                StockAPI.shared.getLogoStock(ticker: individualTicker) { result in
                    switch result {
                    case .failure(let error):
                        print(error)
                    case .success(let imageCompany):
                        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: imageCompany, imageTickerName: "")
                        
                        DispatchQueue.main.async {
                            self.startStopSpinner(start: false)
                            
                            let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
                            guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else { return }
                            
                            destination.exchangeSymbol = self.filteredStocks[index].exchange
                            destination.informationStockTicker = tickerCurrentValues
                            destination.nameTicker = tickerFeatures.nameTicker
                            destination.imageCompany = tickerFeatures.imageTicker
                            destination.modalTransitionStyle = .crossDissolve
                            self.navigationController?.pushViewController(destination, animated: true)
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.startStopSpinner(start: false)
                    ShowAlerts.showSimpleAlert(title: "Error", message: error.localizedDescription, titleButton: "Ok", over: self)
                }
            }
        }
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
        
        guard !searchText.isEmpty else {
            filteredStocks.removeAll()
            stocks.removeAll()
            tableView.reloadData()
            return
        }
        // Fire search only after user pauses typing for 0.4s
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.filterContentForSearchText(searchText)
        }
    }
    
    func filterContentForSearchText(_ searchText: String) {
        searchStocks(ticker: searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredStocks.removeAll()
        stocks.removeAll()
    }
}
