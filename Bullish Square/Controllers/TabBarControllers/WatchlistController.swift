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
    var tickersValues: [TickersCurrentValues] = []
    var timeRange: String = "&interval=1d&range=1d"
    let savedTickers = SaveTickers()
    var refreshControl = UIRefreshControl()
    var alreadyLaunched = false
    var percentageChg = 0.0
    var loadStocks = false //Implemented when the updating for the new version 2.0.0, old database had different information. Temporal until everyone is on version 2.0.0 and more
//    var spinner = UIActivityIndicatorView(style: .large)
    private let imageViewTopRightButton = UIImageView(image: UIImage(named: "plus.square.on.square"))
    private let imageViewPerformanceButton = UIImageView(image: UIImage(named: "chart.line.uptrend.xyaxis.circle"))
    
    //MARK: Outlets and IBActions
    @IBOutlet var tableView: UITableView!
    
    //MARK: Initials
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUITopRightButton()
        
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
            self.showFirstTimeNotification(whereView: self.imageViewTopRightButton)
        }
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let appversionCharacter = appVersion.first!
        
        
        if appversionCharacter.wholeNumberValue! >= 2 {
            loadStocks = true
            let loadSavedTickers = self.savedTickers.loadTickers()
            if !loadSavedTickers.isEmpty {
                self.loadMultipleStocks(savedTickers: loadSavedTickers)
            } else {
                self.startStopSpinner(start: false)
            }
        } else {
            loadStocks = false
//            savedTickers.deleteAllTickers()
            startStopSpinner(start: false)

            
//             Create the alert controller
            let alertController = UIAlertController(title: "Reinstall", message: "Uninstall App and download again!", preferredStyle: .alert)
            
            // Create the actions
            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                UIAlertAction in
                exit(0)
            }
            
            // Add the actions
            alertController.addAction(okAction)
            
            // Present the controller
            self.present(alertController, animated: true, completion: nil)
            
            
        }
        
    }
    
    func addingTicker() {
        
        let vc = SearchStocksController()
        vc.delegate = self
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        let loadSavedTickers = savedTickers.loadTickers()
        loadMultipleStocks(savedTickers: loadSavedTickers)
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
    
    func loadMultipleStocks(savedTickers: [TickersFeatures]) {
        var mergedTickers = ""
        
        for (index, savedTicker) in savedTickers.enumerated() {
           
                if savedTicker.imageTickerName == "mw-logo" {
                    loadImageStock(individualTicker: savedTicker.ticker, nameTicker: savedTicker.nameTicker)
                }
            
            
            let ticker = savedTicker.ticker
            if index == 0 {
                mergedTickers = ticker
            } else {
                mergedTickers = mergedTickers + "," + ticker
            }
        }
        
        StockAPI.shared.getPriceMultipleStocks(tickersGroup: mergedTickers, timeRange: timeRange) { result in
            switch result {
                
            case .success(let tickersGroupPrices):
                print (tickersGroupPrices)
                
                self.tickersFeatures = savedTickers
                self.tickersValues = tickersGroupPrices
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.startStopSpinner(start: false)
                }
                
            case .failure(let error):
                print (error)
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                    self.startStopSpinner(start: false)
                }
            }
        }
    }
    
    func loadImageStock(individualTicker: String, nameTicker: String) {
        
        StockAPI.shared.getLogoStock(ticker: individualTicker) { result in
            switch result {
            case .failure(let error):
                print (error)
            case .success(let imageCompany):
                
                let tempTickerValues = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: imageCompany, imageTickerName: "mw-logo")
                self.savedTickers.deleteTicker(tickerFeatures: tempTickerValues)
                print ("deleted ticker temporal \(tempTickerValues)")
                
                let newTickerValues = TickersFeatures(ticker: individualTicker, nameTicker: nameTicker, imageTicker: imageCompany, imageTickerName: individualTicker)
                self.savedTickers.saveTicker(tickerFeatures: newTickerValues)
                print ("saved new ticker \(self.savedTickers.loadTickers())")
                
            }
        }
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "myTickersCell", for: indexPath) as! WatchlistViewCell
                
        cell.tickerLabel.text = " "
        cell.currentPriceLabel.text = "$0.0"
        cell.nameCompanyLabel.text = " "
        
        cell.changeLabel.text = "%"
        cell.previousPriceLabel.text = "$0.0"
        
        let ticker = tickersFeatures[indexPath.row].ticker
        if ticker != "" {
            
            let name = tickersFeatures[indexPath.row].nameTicker
            let image = tickersFeatures[indexPath.row].imageTicker
            let marketPrice = tickersValues[indexPath.row].marketPrice
            if marketPrice != 0.0  {
                cell.currentPriceLabel.text = "$\(marketPrice)"
            }
            
            var previousPrice = tickersValues[indexPath.row].previousPrice
            var percentage = tickersValues[indexPath.row].changePercent
            previousPrice = Double(round(100*previousPrice)/100)
            percentage = Double(round(100*percentage)/100)
            
            cell.tickerLabel.text = ticker
            cell.imageCompanyImageView.image = image
            cell.nameCompanyLabel.text = name
            
            cell.changeLabel.text = String(percentage) + "%"
            cell.previousPriceLabel.text = "$" + String(previousPrice)
            
            if percentage < 0 {
                cell.changeLabel.textColor = UIColor(named: "downtrend")  //UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                cell.previousPriceLabel.textColor = UIColor(named: "downtrend")   //UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                cell.arrowImageView.image = (UIImage.init(systemName: "arrow.down.app.fill"))
                cell.arrowImageView.tintColor = UIColor(named: "downtrend") //UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                cell.frameCoverLabel.backgroundColor = UIColor(named: "downtrend") //UIColor(named: "downtrend") //UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1)
                
                cell.currentPriceLabel.backgroundColor = UIColor(named: "downtrend")
                cell.currentPriceLabel.textColor = UIColor.white
            } else {
                cell.changeLabel.textColor = UIColor(named: "uptrend")  //UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                cell.previousPriceLabel.textColor = UIColor(named: "uptrend")  //UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                cell.arrowImageView.image = (UIImage.init(systemName: "arrow.up.square.fill"))
                cell.arrowImageView.tintColor = UIColor(named: "uptrend") //UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                cell.frameCoverLabel.backgroundColor = UIColor(named: "uptrend") //UIColor(named: "uptrend") //UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 0.7)
             
                cell.currentPriceLabel.backgroundColor = UIColor(named: "uptrend")
                cell.currentPriceLabel.textColor = UIColor(named: "colorPrimary")
            }
            
            cell.openChartButton.tag = indexPath.row
            cell.openChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        }
        
        return cell
    }
    
    @objc func openChart(sender: UIButton) {
        let tickerFeatures = tickersFeatures[sender.tag]
        let tickkerValues = tickersValues[sender.tag]
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        guard let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController else {
            print("Failed to instantiate ChartController")
            return
        }
        let tickerCurrentValues = TickersCurrentValues(ticker: tickkerValues.ticker, marketPrice: tickkerValues.marketPrice, previousPrice: tickkerValues.previousPrice, changePercent: tickkerValues.changePercent)
        
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
            savedTickers.deleteTicker(tickerFeatures: tickerFeatures)
            
            tickersValues.remove(at: indexPath.row)
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
        
        let tapGestureRecognizerPerformance = UITapGestureRecognizer(target: self, action: #selector(performanceSimulatorTapped(tapGestureRecognizer:)))
        imageViewPerformanceButton.isUserInteractionEnabled = true
        imageViewPerformanceButton.tintColor = UIColor(named: "colorSecondary")
        imageViewPerformanceButton.addGestureRecognizer(tapGestureRecognizerPerformance)
        
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewTopRightButton)
        navigationBar.addSubview(imageViewPerformanceButton)
        imageViewPerformanceButton.translatesAutoresizingMaskIntoConstraints = false
        imageViewTopRightButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageViewTopRightButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -ConstTopRightButton.ImageRightMargin),
            imageViewTopRightButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -ConstTopRightButton.ImageBottomMarginForLargeState),
            imageViewTopRightButton.heightAnchor.constraint(equalToConstant: ConstTopRightButton.ImageSizeForLargeState),
            imageViewTopRightButton.widthAnchor.constraint(equalTo: imageViewTopRightButton.heightAnchor),
            imageViewPerformanceButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(imageViewTopRightButton.frame.width*2.9)),
            imageViewPerformanceButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -ConstTopRightButton.ImageBottomMarginForLargeState),
            imageViewPerformanceButton.heightAnchor.constraint(equalToConstant: ConstTopRightButton.ImageSizeForLargeState),
            imageViewPerformanceButton.widthAnchor.constraint(equalTo: imageViewTopRightButton.heightAnchor)
        ])
    }
    
    @objc func performanceSimulatorTapped(tapGestureRecognizer: UITapGestureRecognizer) {
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
        let loadSavedTickers = savedTickers.loadTickers()
        if !loadSavedTickers.isEmpty {
            loadMultipleStocks(savedTickers: loadSavedTickers)
        } else {
            self.startStopSpinner(start: false)
        }
    }
    
    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageViewTopRightButton.alpha = show ? 1.0 : 0.0
            self.imageViewPerformanceButton.alpha = show ? 1.0 : 0.0
        }
    }
}
