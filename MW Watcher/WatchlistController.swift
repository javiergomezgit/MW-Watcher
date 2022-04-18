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
    var tickers: [Tickers] = []
    var timeRange: String = "&interval=1d&range=1d"
    let savedTickers = SaveTickers()
    var refreshControl = UIRefreshControl()
    var alreadyLaunched = false
    var percentageChg = 0.0
    var spinner = UIActivityIndicatorView(style: .large)
    
    //MARK: Outlets and IBActions
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var addTickerButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var chosingTimeSegment: UISegmentedControl!
    
    
    //MARK: Initials
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionLabel.text = appVersion
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingWatchlist")
        UserDefaults.standard.set(true, forKey: "firstLaunchingWatchlist")
        UserDefaults.standard.synchronize()
        
        //change to true for testing
        if !isFirstLaunch {
            alreadyLaunched = false
        } else {
            alreadyLaunched = true
        }
        
        let font = UIFont.boldSystemFont(ofSize: 16)
        let titleTextAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        
        chosingTimeSegment.setTitleTextAttributes(titleTextAttributes, for: .normal)
        chosingTimeSegment.setTitleTextAttributes(titleTextAttributes, for: .selected)
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl) // not required when using UITableViewController
        
        
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
            self.showFirstTimeNotification(whereView: self.addTickerButton)
        }
        
        let loadSavedTickers = self.savedTickers.loadTickers()
        if !loadSavedTickers.isEmpty {
            self.loadMultipleStocks(savedTickers: loadSavedTickers)
        }
    }
    
    @IBAction func addingTicker(_ sender: UIButton) {
        let alert = ShowAlerts.inputTextAlert(title: "Add a new ticker", message: "Please type a new ticker for the watchlist")
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { _ in
            
            guard let field = alert.textFields else { return }
            let fieldArray = field.first
            guard let tickerToAdd = fieldArray!.text, !tickerToAdd.isEmpty else {
                ShowAlerts.showSimpleAlert(title: "Empty field", message: "You need to type your ticker", titleButton: "Ok", over: self)
                return
            }
            var alreadyOnList = false
            for tick in self.tickers {
                if tick.ticker == tickerToAdd {
                    alreadyOnList = true
                }
            }
            if !alreadyOnList {
                self.loadIndividualStock(individualTicker: tickerToAdd)
            } else {
                ShowAlerts.showSimpleAlert(title: "Already added", message: "Your stock was already added", titleButton: "Ok", over: self)
            }
        }))
        present(alert, animated: true)
    }
    
    @IBAction func chosingTime(_ sender: UISegmentedControl) {
        let loadSavedTickers = savedTickers.loadTickers()
        
        switch sender.selectedSegmentIndex {
        case 0:
            timeRange = "&interval=1d&range=1d"
        case 1:
            timeRange = "&interval=1d&range=5d"
        case 2:
            timeRange = "&interval=1wk&range=3mo"
        default:
            break
        }
        if !loadSavedTickers.isEmpty {
            tickers.removeAll()
            loadMultipleStocks(savedTickers: loadSavedTickers)
        }
    }
    
    @objc func refresh(_ sender: AnyObject) {
        let loadSavedTickers = savedTickers.loadTickers()
        loadMultipleStocks(savedTickers: loadSavedTickers)
        tableView.reloadData()
    }
    
    func showFirstTimeNotification(whereView: UIView) {
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX - 70, y: whereView.frame.minY - 30, width: 100, height: 100)
        popTip.show(text: "Add your favorite stocks", direction: .left, maxWidth: 100, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
    }
    
    func loadMultipleStocks(savedTickers: [String]){
        var mergedTickers = ""
        for (index, savedTicker) in savedTickers.enumerated() {
            if index == 0 {
                mergedTickers = savedTicker
            } else {
                mergedTickers = mergedTickers + "," + savedTicker
            }
        }
        
        StocksAPI.shared.getPriceMultipleStocks(tickersGroup: mergedTickers, timeRange: timeRange) { result in
            switch result {
                
            case .success(let groupStockPrices):
                print (groupStockPrices)
                self.tickers = groupStockPrices
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                }
                
            case .failure(let error):
                print (error)
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                }
            }
        }
    }
    
    func loadIndividualStock(individualTicker: String) {
        
        StocksAPI.shared.getPriceSingleStock(tickerSingle: individualTicker, timeRange: timeRange) { result in
            switch result {
                
            case .success(let individualStockPrice):
                self.savedTickers.saveTicker(ticker: individualTicker)
                self.tickers.append(Tickers(ticker: individualTicker, marketPrice: individualStockPrice.marketPrice, previousPrice: individualStockPrice.previousPrice))
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title:  "Added", message: "We added \(individualTicker) to the watchlist", titleButton: "Ok", over: self)
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                }
            case .failure(let error):
                print (error.localizedDescription)
                print (error)
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "We couldn't find the ticker", titleButton: "Ok", over: self)
                }
            }
        }
    }
}


//Customs
//Delegate for table view
extension WatchlistController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "myTickersCell", for: indexPath) as! WatchlistViewCell
        cell.tickerLabel.text = tickers[indexPath.row].ticker
        cell.currentPriceLabel.text = "$" + String(tickers[indexPath.row].marketPrice)
        
        let percentageChange = (tickers[indexPath.row].marketPrice * 100) / tickers[indexPath.row].previousPrice
        if percentageChange < 100 {
            var percentageRounded = 100 - percentageChange
            percentageRounded = Double(round(100*percentageRounded)/100)
            
            cell.changeLabel.text = "- " + String(percentageRounded) + "%"
            cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            
            let previousPrice = Double(round(100*tickers[indexPath.row].previousPrice)/100)
            cell.previousPriceLabel.text = "PREV. $" + String(previousPrice)
            cell.previousPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            
            cell.imageArrow.image = (UIImage.init(systemName: "arrow.down.app.fill"))
            cell.imageArrow.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            var percentageRounded = percentageChange - 100
            percentageRounded = Double(round(100*percentageRounded)/100)
            
            cell.changeLabel.text = "+ " + String(percentageRounded) + "%"
            cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            
            let previousPrice = Double(round(100*tickers[indexPath.row].previousPrice)/100)
            cell.previousPriceLabel.text = "PREV. $" + String(previousPrice)
            cell.previousPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            
            cell.imageArrow.image = (UIImage.init(systemName: "arrow.up.square.fill"))
            cell.imageArrow.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        cell.buttonTickerNews.tag = indexPath.row
        cell.buttonTickerNews.addTarget(self, action: #selector(openNews(sender:)), for: .touchUpInside)
        
        cell.buttonOpenChart.tag = indexPath.row
        cell.buttonOpenChart.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func openChart(sender: UIButton) {
        let ticker = self.tickers[sender.tag]
        print (self.tickers[sender.tag])
        
        let perChange = (ticker.marketPrice * 100) / ticker.previousPrice
        var percentageRounded = 100 - perChange
        percentageRounded = Double(round(100*percentageRounded)/100) * -1
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = Tickers(ticker: ticker.ticker, marketPrice: ticker.marketPrice, previousPrice: percentageRounded)
        destination?.informationStockTicker = tickerWithChange
        
        self.show(destination!, sender: self)
    }
    
    @objc func openNews(sender: UIButton) {
        let ticker = self.tickers[sender.tag].ticker
        
        print (sender.tag)
        print (ticker)
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "TickerNewsController") as? TickerNewsController
        
        destination!.ticker = ticker
        
        //    nextViewController.modalPresentationStyle = .fullScreen
        //    nextViewController.modalTransitionStyle = .crossDissolve
        self.show(destination!, sender: self)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let ticker = tickers[indexPath.row].ticker
            savedTickers.deleteTickers(ticker: ticker, deleteAll: false)
            
            tickers.remove(at: indexPath.row)
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

