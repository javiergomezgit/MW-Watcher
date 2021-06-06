//
//  MyTickersController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import Foundation
import LocalAuthentication

struct Tickers {
    let ticker: String
    let marketPrice: Double
    let previousPrice: Double
}

class MyTickersController: UIViewController {

    //MARK: Variables
    var tickers: [Tickers] = []
    var timeRange: String = "&interval=1d&range=1d"
    let savedTickers = SaveMyTickers()
    var refreshControl = UIRefreshControl()

    //MARK: Outlets and IBActions
    @IBOutlet var tableView: UITableView!

    @IBAction func addingTicker(_ sender: UIButton) {
        let alert = UIAlertController(title: "Add a new ticker", message: "Please type a new ticker for the watchlist", preferredStyle: .alert)

        alert.addTextField { field in
            field.placeholder = "TICKER"
            field.clearButtonMode = .always
            field.autocorrectionType = .no
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.smartInsertDeleteType = .no
            field.spellCheckingType = .no
            field.keyboardType = .alphabet
            field.returnKeyType = .default
            field.keyboardType = .default
            field.autocapitalizationType = .allCharacters
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { _ in
        
            guard let field = alert.textFields else { return }
            let fieldArray = field.first
            guard let ticker = fieldArray!.text, !ticker.isEmpty else {
                self.showAlert(title: "Empty field", message: "You need to type your ticker", titleButton: "OK")
                return
            }
            self.loadTicker(loadSingle: ticker, loadMultiple: nil)
        }))
        present(alert, animated: true)
    }
    @IBOutlet weak var chosingTimeSegment: UISegmentedControl!
    
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
            loadTicker(loadSingle: nil, loadMultiple: loadSavedTickers)
        }
    }
    
    
    //MARK: Initials
    override func viewDidLoad() {
        super.viewDidLoad()
        
        authenticationWithTouchID()
        
        let font = UIFont.boldSystemFont(ofSize: 16)
        let titleTextAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
                
        chosingTimeSegment.setTitleTextAttributes(titleTextAttributes, for: .normal)
        chosingTimeSegment.setTitleTextAttributes(titleTextAttributes, for: .selected)
        
        //TODO: Improve loading / load only once for all time, then make the calculation of times based on the picked segment control
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl) // not required when using UITableViewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        authenticationWithTouchID()
    }
    
    @objc func refresh(_ sender: AnyObject) {
        let loadSavedTickers = savedTickers.loadTickers()
        loadTicker(loadSingle: nil, loadMultiple: loadSavedTickers)
        tableView.reloadData()
    }
    
    
    //MARK: Network connections
    func loadTicker(loadSingle: String?, loadMultiple: [String]?) {
        let headers = [
            "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
            "x-rapidapi-host": "apidojo-yahoo-finance-v1.p.rapidapi.com"
        ]
        
        var ticker = ""
        var url = ""
        var json: [String: Any]? = [:]
        
        if loadSingle != nil {
            ticker = loadSingle!
            url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + ticker + timeRange
        } else {
            for singleTicker in loadMultiple! {
                ticker = ticker + "%2C" + singleTicker
            }
            url = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/get-spark?symbols=" + ticker + timeRange
        }
        
        print (url)

        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        print (request.description)

        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
                print(error!)
                self.showAlert(title: "Error", message: String(error.debugDescription), titleButton: "Try later")
            } else {
                //let httpResponse = response as? HTTPURLResponse
                json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                if json == nil  {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Error", message: "We couldn't connect", titleButton: "Try later")
                    }
                    return
                }
                
                if let tickerFound = json![ticker] {
                    //SINGLE TICKER
                    let tickerDictionary = tickerFound as? [String: Any]
                    
                    let foundClose = tickerDictionary!["chartPreviousClose"]
                    
                    guard let previousClose = foundClose as? Double else {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Error", message: "We couldn't find the ticker", titleButton: "Try later")
                        }
                        return
                    }
                    
                    let closePriceArray = tickerDictionary!["close"] as? [Any]
                    let closePrice = closePriceArray!.last as! Double
                    
                    self.savedTickers.saveTicker(ticker: ticker)
                    self.tickers.append(Tickers(ticker: ticker, marketPrice: closePrice, previousPrice: previousClose))
                    print (self.tickers)
                    DispatchQueue.main.async {
                        self.showAlert(title: "ADDED", message: "We added \(ticker) to the watchlist", titleButton: "OK")
                        self.tableView.reloadData()
                        self.refreshControl.endRefreshing()
                    }
                    
                } else {
                    //MULTIPLE TICKER
                    if loadMultiple != nil {
                        self.tickers.removeAll()
                        var tickersWithoutSorting : [Tickers] = []
                        for tickerJSON in json! {
                            print (tickerJSON.value) //json
                            print (tickerJSON.key) //ticker
                            
                            let tickerDictionary = tickerJSON.value as? [String: Any]
                            let previousClose = tickerDictionary!["chartPreviousClose"] as! Double
                            let closePriceArray = tickerDictionary!["close"] as? [Any]
                            let closePrice = closePriceArray!.last as! Double
                            tickersWithoutSorting.append(Tickers(ticker: tickerJSON.key, marketPrice: closePrice, previousPrice: previousClose))
                        }
                                            
                        self.tickers = tickersWithoutSorting.sorted{ $0.ticker < $1.ticker }
                        
                        print (self.tickers)
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                            self.refreshControl.endRefreshing()
                        }
                    } else  {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Not Found", message: "Ticker not found", titleButton: "OK")
                        }
                    }
                }
            }
        })
        dataTask.resume()
    }
    
}


//Customs
extension MyTickersController {
    func showAlert(title: String, message: String, titleButton: String) {
        let dialogMessage = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: titleButton, style: .default, handler: { (action) -> Void in
            print("Ok button tapped")
         })
        dialogMessage.addAction(ok)
        self.present(dialogMessage, animated: true, completion: nil)
    }
}

//Delegate for table view
extension MyTickersController: UITableViewDelegate, UITableViewDataSource {
  
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tickers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "myTickersCell", for: indexPath) as! MyTickersViewCell
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
        
        return cell
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
extension MyTickersController {
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


//Delegate for authentication with Biometrics
extension MyTickersController {
    
    func authenticationWithTouchID() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"

        var authError: NSError?
        let reasonString = "To access the secure data"

        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString) { success, evaluateError in
                
                DispatchQueue.main.async {
                    if success {
                        
                        //TODO: User authenticated successfully, take appropriate action
                        let loadSavedTickers = self.savedTickers.loadTickers()
                        
                        if !loadSavedTickers.isEmpty {
                            self.loadTicker(loadSingle: nil, loadMultiple: loadSavedTickers)
                        }
                        
                    } else {
                        //TODO: User did not authenticate successfully, look at error and take appropriate action
                        
                        guard let error = evaluateError else {
                            return
                        }
                        
                        print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                        //TODO: If you have choosen the 'Fallback authentication mechanism selected' (LAError.userFallback). Handle gracefully
                        
                    }
                }
                
            }
        } else {
            
            guard let error = authError else {
                return
            }
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error.code))
        }
    }
    
    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
        var message = ""
        if #available(iOS 11.0, macOS 10.13, *) {
            switch errorCode {
                case LAError.biometryNotAvailable.rawValue:
                    message = "Authentication could not start because the device does not support biometric authentication."
                
                case LAError.biometryLockout.rawValue:
                    message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
                
                case LAError.biometryNotEnrolled.rawValue:
                    message = "Authentication could not start because the user has not enrolled in biometric authentication."
                
                default:
                    message = "Did not find error code on LAError object"
            }
        } else {
            switch errorCode {
                case LAError.touchIDLockout.rawValue:
                    message = "Too many failed attempts."
                
                case LAError.touchIDNotAvailable.rawValue:
                    message = "TouchID is not available on the device"
                
                case LAError.touchIDNotEnrolled.rawValue:
                    message = "TouchID is not enrolled on the device"
                
                default:
                    message = "Did not find error code on LAError object"
            }
        }
        
        return message;
    }
    
    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        
        var message = ""
        
        switch errorCode {
            
        case LAError.authenticationFailed.rawValue:
            message = "The user failed to provide valid credentials"
            
        case LAError.appCancel.rawValue:
            message = "Authentication was cancelled by application"
            
        case LAError.invalidContext.rawValue:
            message = "The context is invalid"
            
        case LAError.notInteractive.rawValue:
            message = "Not interactive"
            
        case LAError.passcodeNotSet.rawValue:
            message = "Passcode is not set on the device"
            
        case LAError.systemCancel.rawValue:
            message = "Authentication was cancelled by the system"
            
        case LAError.userCancel.rawValue:
            message = "The user did cancel"
            
        case LAError.userFallback.rawValue:
            message = "The user chose to use the fallback"

        default:
            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
        }
        
        return message
    }
}
    










