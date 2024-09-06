//
//  SearchNewsController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

class SearchNewsController: UIViewController {
    
    public var completion: (([String: String]) -> (Void))?
    private var stocks = [Stock]()
    private var filteredStocks = [Stock]()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for news"
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(SearchNewsViewCell.self, forCellReuseIdentifier: SearchNewsViewCell.identifier)
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(didTapDismiss))
        searchBar.becomeFirstResponder()
        searchBar.autocapitalizationType = .allCharacters
        
        definesPresentationContext = true
    }
    
    @objc private func didTapDismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    private func searchStocks(ticker: String) {
        StocksAPI.shared.searchStocks(ticker: ticker) { stocks, error in
            if stocks != nil {
                print (stocks as Any)
                self.stocks.removeAll()
                self.filteredStocks.removeAll()
                
                self.stocks = stocks!
                self.filteredStocks = stocks!
                if stocks!.count != 0 {
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } else {
                print (error as Any)
            }
        }
    }
}

extension SearchNewsController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredStocks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchNewsViewCell.identifier, for: indexPath) as! SearchNewsViewCell
        if filteredStocks.count > 0 {
            let ticker = filteredStocks[indexPath.row]
            cell.configure(ticker: ticker.ticker, name: ticker.nameTicker)
        }
        return cell

    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        searchBar.resignFirstResponder()
        tableView.deselectRow(at: indexPath, animated: true)
        
        if filteredStocks.count > 0 {
            let stock = filteredStocks[indexPath.row]
            self.dismiss(animated: true, completion: { [weak self] in
                let tickerAndName = [stock.ticker : stock.nameTicker]
                self?.completion?(tickerAndName)
            })
        }
        
    }
}

extension SearchNewsController: UISearchBarDelegate {//UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredStocks.removeAll()
        guard let searchBarText = searchBar.text, !searchBarText.isEmpty else {
            return
        }
        filterContentForSearchText(searchBarText)
    }
    
    func filterContentForSearchText(_ searchText: String) {
        searchStocks(ticker: searchText)
        
        filteredStocks = searchText.isEmpty ? stocks : stocks.filter({ stock in
            return stock.ticker.range(of: searchText, options: .caseInsensitive, range: nil, locale: nil) != nil
        })
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredStocks.removeAll()
        stocks.removeAll()
    }
}

