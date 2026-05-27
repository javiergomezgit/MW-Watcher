//
//  SearchStockController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

// delegate protocol
protocol SearchStocksControllerDelegate: AnyObject {
    func searchStocksControllerDidDismiss(_ controller: SearchStocksController)
}

class SearchStocksController: UIViewController, SearchStocksViewCellDelegate {
    weak var delegate: SearchStocksControllerDelegate? // Add delegate property

    private var stocks = [Stock]()
    private var filteredStocks = [Stock]()
    private var watchlist: Set<String> = [] // Track added tickers
    var timeRange: String = "&interval=1d&range=1d"
    private var searchTimer: Timer?
    
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
        
        loadWatchlist() // Load watchlist to initialize isAdded states
    }
    
    @objc private func didTapDismiss() {
        delegate?.searchStocksControllerDidDismiss(self) // Notify delegate
        dismiss(animated: true, completion: nil)
    }
    
    private func loadWatchlist() {
        
        let loadSavedTickers = SaveTickers().loadTickers()
        
        for loadSavedTicker in loadSavedTickers {
            watchlist.insert(loadSavedTicker.ticker)
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Fetches stocks from API and reloads the table.
    // Uses reloadSections instead of reloadData to force full cell reconfiguration,
    // preventing stale ticker values from carrying over between searches.
    private func searchStocks(ticker: String) {
        StockAPI.shared.searchStocks(ticker: ticker) { stocks, error in
            guard let stocks = stocks, !stocks.isEmpty else {
                print (error as Any)
                return
            }
            
            DispatchQueue.main.async {
                self.stocks = stocks
                self.filteredStocks = stocks
                //self.tableView.reloadData()
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            }
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
}

extension SearchStocksController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredStocks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchStocksViewCell.identifier, for: indexPath) as! SearchStocksViewCell
        
        guard indexPath.row < filteredStocks.count else { return cell }
        let ticker = filteredStocks[indexPath.row]
        let isAdded = watchlist.contains(ticker.ticker)
        cell.prepareForReuse()
        cell.configure(ticker: ticker.ticker, name: ticker.nameTicker, exchange: ticker.exchange, isAdded: isAdded)
        cell.delegate = self
        
        return cell
    }
    
    func didTapAddButton(in cell: SearchStocksViewCell, isAdded: Bool, ticker: String) {
        for stock in self.filteredStocks {
            if stock.ticker == ticker {
                if isAdded {
                    saveIndividualStock(individualTicker: stock.ticker, nameTicker: stock.nameTicker)
                } else {
                    deleteIndividualStock(individualTicker: stock.ticker, nameTicker: stock.nameTicker)
                }
            }
        }
    }
    
    func deleteIndividualStock(individualTicker: String, nameTicker: String) {
        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: UIImage(named: "mw-logo")!, imageTickerName: "mw-logo")
        self.watchlist.remove(individualTicker)
        SaveTickers().deleteTicker(tickerFeatures: tickerFeatures)
    }
    
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
    

    
    
    @objc func openChart(index: Int) {
        print (index)
        
        let individualTicker = filteredStocks[index].ticker
        let nameTicker = filteredStocks[index].nameTicker
        
        self.startStopSpinner(start: true)
        
        StockAPI.shared.getPriceSingleTicker(ticker: individualTicker, timeRange: self.timeRange) { result in
            switch result {
            case .success(let tickerCurrentValues):
                StockAPI.shared.getLogoStock(ticker: individualTicker) { result in
                    switch result {
                    case .failure(let error):
                        print (error)
                    case .success(let imageCompany):
                        let tickerFeatures = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: imageCompany, imageTickerName: "")
                        
                        DispatchQueue.main.async {
                            self.startStopSpinner(start: false)
                            
                            let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
                            let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
                            
                            destination?.exchangeSymbol = self.filteredStocks[index].exchange
                            destination?.informationStockTicker = tickerCurrentValues
                            destination?.nameTicker = tickerFeatures.nameTicker
                            destination?.imageCompany = tickerFeatures.imageTicker
                            destination?.modalTransitionStyle = .crossDissolve
                            self.navigationController?.pushViewController(destination!, animated: true)

                        }
                    }
                }
                
            case .failure(let error):
                print (error.localizedDescription)
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

