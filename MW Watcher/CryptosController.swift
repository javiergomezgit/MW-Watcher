//
//  CryptoMarkets.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import UIKit

class CryptosController: UIViewController {
        
    private var viewModels = [CryptosViewCellModel]()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(CryptosViewCell.self, forCellReuseIdentifier: "CryptosViewCell")
        return tableView
    }()
    
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.allowsFloats = true
        formatter.numberStyle = .currency
        formatter.formatterBehavior = .default
        
        return formatter
    }()
    
    override func viewDidLoad() {
        
        
        
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        
        CryptosAPI.shared.getAllIcons()
        
        loadCryptoPrices()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    
    
    func loadCryptoPrices() {
        CryptosAPI.shared.getAllCryptosData { [weak self] result in
            switch result {
            case .success(let models):
                self?.viewModels = models.compactMap({ model in
                    let price = model.price_usd ?? 0
                    let formatter = CryptosController.numberFormatter
                    let pricesString = formatter.string(from: NSNumber(value: price))
                    
                    let iconUrl = URL(
                        string:
                            CryptosAPI.shared.icons.filter({ icon in
                                icon.asset_id == model.asset_id
                            }).first?.url ?? ""
                        )
                    
                    return CryptosViewCellModel(
                        name: model.name ?? "N/A",
                        symbol: model.asset_id,
                        price: pricesString ?? "N/A",
                        iconUrl: iconUrl
                    )
                })
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                //print (models)
                print (models.count)
            case .failure(let error):
                print (error)
            }
        }
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80
    }

}


/* crypto
 let headers = [
     "x-rapidapi-key": "a0ff2468bbmsh246d9d651a69c21p1a186bjsn6b734187f148",
     "x-rapidapi-host": "alpha-vantage.p.rapidapi.com"
 ]

 let request = NSMutableURLRequest(url: NSURL(string: "https://alpha-vantage.p.rapidapi.com/query?market=usd&symbol=BTC&function=DIGITAL_CURRENCY_DAILY")! as URL,
                                         cachePolicy: .useProtocolCachePolicy,
                                     timeoutInterval: 10.0)
 request.httpMethod = "GET"
 request.allHTTPHeaderFields = headers

 let session = URLSession.shared
 let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
     if (error != nil) {
         print(error)
     } else {
         let httpResponse = response as? HTTPURLResponse
         print(httpResponse)
     }
 })

 dataTask.resume()
 */

