//
//  CryptoMarkets.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import UIKit

class CryptosController: UIViewController {
    
    private var cryptoData: [CryptoData]?
    private var viewModels = [CryptosViewCellModel]()
    
    @IBOutlet var tableView: UITableView!
    var refreshControl = UIRefreshControl()
    
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.allowsFloats = true
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let volumeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        formatter.groupingSeparator = ","
        return formatter
    }()
    
    override func viewDidLoad() {
        
        tableView.register(CryptosViewCell.self, forCellReuseIdentifier: "CryptosViewCell")
        
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Loading")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        loadCryptoPrices()
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadCryptoPrices()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func loadCryptoPrices() {
        CryptosAPI.shared.getAllCryptosData { [weak self] result in
            switch result {
            case .success(let data):
                
                self?.cryptoData = data
                DispatchQueue.main.async {
                    self?.setUpViewModel()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    ShowAlerts.showSimpleAlert(title: "Try later!", message: "We couldn't download the information", titleButton: "OK", over: self!)
                }
                print (error)
            }
        }
    }
    
    private func setUpViewModel() {
        
        guard let models = cryptoData else { return }
        
        let cryptosSortedByVolume = models.sorted { first, second -> Bool in
            return first.quote["USD"]!.volume_24h > second.quote["USD"]!.volume_24h
        }
        
        for model in cryptosSortedByVolume {
            guard let price = model.quote["USD"]?.price else { return }
            guard let change = model.quote["USD"]?.percent_change_24h else { return }
            guard let changeMonth = model.quote["USD"]?.percent_change_30d else { return }
            guard let volume = model.quote["USD"]?.volume_24h else { return }
            
            let number = NSNumber(value: price)
            let stringPrice = CryptosController.numberFormatter.string(from: number)
            
            let percent = NSNumber(value: change)
            let percentDay = CryptosController.percentFormatter.string(from: percent)
            
            let percentM = NSNumber(value: changeMonth)
            let percentMonth = CryptosController.percentFormatter.string(from: percentM)
            
            let volumeReduce = NSNumber(value: (volume/1000000))
            let volume24hr = CryptosController.volumeFormatter.string(from: volumeReduce)
            
            viewModels.append(CryptosViewCellModel(symbol: model.symbol, name: model.name, price: stringPrice!, change: percentDay!, changeMonth: percentMonth!, volume: volume24hr!, cryptoImage: UIImage(named: model.symbol)!))
        }
        self.refreshControl.endRefreshing()
        tableView.reloadData()
    }
    
    @objc func openChart(sender: UIButton) {
        //let symbol = self.viewModels[sender.tag].symbol
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "ChartController") as? ChartController
        
        destination!.informationCryptoTicker = self.viewModels[sender.tag]
        destination!.modalTransitionStyle = .crossDissolve
        self.present(destination!, animated: true, completion: nil)
        //    nextViewController.modalTransitionStyle = .crossDissolve
        
    }
}


// MARK: - Table Delegate
extension CryptosController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CryptosViewCell", for: indexPath) as! CryptosViewCell
        cell.configure(with: viewModels[indexPath.row])
        
        cell.openCryptoChartButton.tag = indexPath.row
        cell.openCryptoChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        100
    }
    
}
