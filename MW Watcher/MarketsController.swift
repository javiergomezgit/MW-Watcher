//
//  MarketsWatcherController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit
import DGCharts

class MarketsController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var chartView: UIView!
    @IBOutlet weak var dateLatestDataLabel: UILabel!
    
    private let imageViewTopRightButton = UIImageView(image: UIImage(named: "arrow.triangle.2.circlepath.circle"))

    var sizeOfCell = CGFloat(0)
    
    private var marketsDataSP500: [MarketsCandles] = []
    private var marketsDataDJI: [MarketsCandles] = []
    private var marketsDataIXIC: [MarketsCandles] = []
    
    private var linearValuesSP500 = [ChartDataEntry]()
    private var linearValuesDJI = [ChartDataEntry]()
    private var linearValuesIXIC = [ChartDataEntry]()
    
    lazy var lineChartView: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        
        lineChartView.dragEnabled = false
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = false
        lineChartView.doubleTapToZoomEnabled = false
        lineChartView.dragXEnabled = false
        lineChartView.autoScaleMinMaxEnabled = true
        lineChartView.legend.enabled = true
        lineChartView.legend.textColor = .label
        
        //TODO: Display value of the selected point in the chart
        //MARK: Display values on the tapped area of the line/candle
//        let marker:BalloonMarker = BalloonMarker(color: UIColor.label, font: UIFont(name: "Helvetica", size: 12)!, textColor: UIColor.systemBackground, insets: UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0))
//        marker.minimumSize = CGSize(width: 75.0, height: 35.0)
//        lineChartView.marker = marker
//        lineChartView.drawMarkers = true
        
        lineChartView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.rightAxis.labelTextColor = .label
        //        lineChartView.rightAxis.spaceTop = 0.5
        //        lineChartView.rightAxis.spaceBottom = 0.3
        lineChartView.rightAxis.setLabelCount(8, force: true)
        lineChartView.rightAxis.axisLineColor = .label
        lineChartView.rightAxis.labelPosition = .outsideChart
        
        lineChartView.xAxis.enabled = false
//        lineChartView.xAxis.labelPosition = .top
//        lineChartView.xAxis.yOffset = 5
//        lineChartView.xAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 9)!
//        lineChartView.xAxis.labelTextColor = .label
//        lineChartView.xAxis.setLabelCount(5, force: true)
        
        return lineChartView
    }()
    
    //    var marketsPrices = [
    //        GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^GSPC", indexName: "S&P 500", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^IXIC", indexName: "Nasdaq Composite", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^W5000", indexName: "Wilshire 5000 Total Market Index", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^RUA", indexName: "Russell 3000", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^SP400", indexName: "S&P 400", indexPrice:  0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker: "^RUT", indexName: "Russell 2000", indexPrice: 0.0, changePercentage: 0.0),
    //        GeneralMarkets(indexTicker:  "^VIX", indexName: "CBOE Volatility Index", indexPrice:  0.0, changePercentage: 0.0)
    //    ]
    
    var majorMarketsPrices = [GeneralMarkets(indexTicker: "^DJI", indexName: "Dow Jones Industrial Average", indexPrice: 0.0, changePercentage: 0.0)]
    
    var minorMarketPrices : [GeneralMarkets] = []
    //     var minorMarketPrices = [GeneralMarkets(indexTicker: "^IXIC", indexName: "Nasdaq Composite", indexPrice: 0.0, changePercentage: 0.0)]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUITopRightButton()
        startStopSpinner(start: true)
        loadMajorMarketsChart()
        loadCurrentPrices()
                
        sizeOfCell = (view.frame.width/3) - (view.frame.width/20)
    }
    
    func updateAllData() {
        startStopSpinner(start: true)
        loadMajorMarketsChart()
        loadCurrentPrices()
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
    
    func loadCurrentPrices() {
        StockAPI.shared.getPriceGeneralMarkets { markets in
            if markets == nil {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
            } else {
                guard let marketsValues = markets else {
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                    return
                }
                self.majorMarketsPrices.removeAll()
                self.minorMarketPrices.removeAll()
                
                self.loadMajorMarkets(marketsValues: marketsValues)
                self.loadMinorMarkets(marketsValues: marketsValues)
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func loadMajorMarkets(marketsValues: [GeneralMarkets]){
        for market in marketsValues {
            let ticker = market.indexTicker
            if ticker == "^DJI" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "DOW JONES", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.majorMarketsPrices.append(newName)
                
            }
            if ticker == "^GSPC" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "S&P 500", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.majorMarketsPrices.append(newName)
            }
            if ticker == "^IXIC" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "NASDAQ", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.majorMarketsPrices.append(newName)
            }
        }
    }
    
    func loadMinorMarkets(marketsValues: [GeneralMarkets]){
        for market in marketsValues {
            let ticker = market.indexTicker
            if ticker == "^VIX" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "CBOE Volatility Index", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^RUT" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Russell 2000", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^SP400" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "S&P 400", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^RUA" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Russell 3000", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
            if ticker == "^W5000" {
                let newName = GeneralMarkets(indexTicker: ticker, indexName: "Wilshire 5000 Total Market Index", indexPrice: market.indexPrice, changePercentage: market.changePercentage)
                self.minorMarketPrices.append(newName)
            }
        }
    }
}

extension MarketsController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return majorMarketsPrices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MarketCell", for: indexPath) as! MarketsViewCell
        
        let tickerValues = majorMarketsPrices[indexPath.row]
        
        cell.nameLabel.text = tickerValues.indexName.uppercased()
        
        var currentPrice = tickerValues.indexPrice
        let percentageChanged = tickerValues.changePercentage
        
        if percentageChanged < 0 {
            let percentageRounded = round(100*percentageChanged)/100
            cell.changeLabel.text = String(percentageRounded) + "%"
            cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            
            currentPrice = round(100*currentPrice)/100
            cell.currentPriceLabel.text = "$ " + String(currentPrice)
            cell.currentPriceLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            
            cell.arrowImageView.image = (UIImage.init(named: "arrow.down.app.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            //positive day for market
            let percentageRounded = round(100*percentageChanged)/100
            cell.changeLabel.text = String(percentageRounded) + "%"
            cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            
            currentPrice = round(100*currentPrice)/100
            cell.currentPriceLabel.text = "$ " + String(currentPrice)
            cell.currentPriceLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            
            cell.arrowImageView.image = (UIImage.init(named: "arrow.up.square.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        cell.openChartButton.tag = indexPath.row
        cell.openChartButton.addTarget(self, action: #selector(openChart(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func openChart(sender: UIButton) {
        let ticker = self.majorMarketsPrices[sender.tag]
        
        let perChange = ticker.changePercentage
        let percentageRounded = round(100*perChange)/100
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = TickersCurrentValues(ticker: ticker.indexTicker, marketPrice: ticker.indexPrice, previousPrice: 0.0, changePercent: percentageRounded)
        destination!.informationStockTicker = tickerWithChange
        destination!.indexName = ticker.indexName
        destination!.indexMarket = true
        
        destination!.modalPresentationStyle = .popover
        destination!.modalTransitionStyle = .crossDissolve
        
        self.present(destination!, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: sizeOfCell, height: (sizeOfCell * 0.80))
    }
}



extension MarketsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return minorMarketPrices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MinorMarketsViewCell", for: indexPath) as! MinorMarketsViewCell
        
        
        let ticker = minorMarketPrices[indexPath.row].indexTicker
        let name = minorMarketPrices[indexPath.row].indexName
        let image = UIImage(named: "mw-logo")
        
        let marketPrice = minorMarketPrices[indexPath.row].indexPrice
        var percentage = minorMarketPrices[indexPath.row].changePercentage
        percentage = Double(round(100*percentage)/100)
        
        cell.tickerLabel.text = ticker.replacingOccurrences(of: "^", with: "")
        cell.currentPriceLabel.text = "$\(marketPrice)"
        cell.imageCompanyImageView.image = image
        cell.nameCompanyLabel.text = name
        cell.changeLabel.text = String(percentage) + "%"
        
        if percentage < 0 {
            cell.changeLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            cell.arrowImageView.image = (UIImage.init(systemName: "arrow.down.app.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
            cell.frameCoverLabel.backgroundColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1)
        } else {
            cell.changeLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            cell.arrowImageView.image = (UIImage.init(systemName: "arrow.up.square.fill"))
            cell.arrowImageView.tintColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
            cell.frameCoverLabel.backgroundColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 0.7)
        }
        
        cell.openChartButton.tag = indexPath.row
        cell.openChartButton.addTarget(self, action: #selector(openChartMinorMarket(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    @objc func openChartMinorMarket(sender: UIButton) {
        let ticker = self.minorMarketPrices[sender.tag]
        
        let perChange = ticker.changePercentage
        let percentageRounded = round(100*perChange)/100
        
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(withIdentifier: "ChartController") as? ChartController
        
        let tickerWithChange = TickersCurrentValues(ticker: ticker.indexTicker, marketPrice: ticker.indexPrice, previousPrice: 0.0, changePercent: percentageRounded)
        destination!.informationStockTicker = tickerWithChange
        destination!.indexName = ticker.indexName
        destination!.indexMarket = true
        
        destination!.modalPresentationStyle = .popover
        destination!.modalTransitionStyle = .crossDissolve
        
        self.present(destination!, animated: true, completion: nil)
    }
}



extension MarketsController: ChartViewDelegate {
    
    func loadMajorMarketsChart() {
        let tickers = ["^DJI", "^GSPC", "^IXIC"]
        ChartAPI.shared.getMajorMarketsValues(symbol: tickers[0]) { result in
            switch result {
            case .success(let marketsValuesDJI):
                self.marketsDataDJI = marketsValuesDJI
                ChartAPI.shared.getMajorMarketsValues(symbol: tickers[1]) { result in
                    switch result {
                    case .success(let marketsValuesSP500):
                        self.marketsDataSP500 = marketsValuesSP500
                        ChartAPI.shared.getMajorMarketsValues(symbol: tickers[2]) { result in
                            switch result {
                            case .success(let marketsValuesIXIC):
                                self.marketsDataIXIC = marketsValuesIXIC
                                DispatchQueue.main.async {
                                    self.startStopSpinner(start: false)
                                    self.setUpMarketModel()
                                }
                            case .failure(_):
                                DispatchQueue.main.async {
                                    self.startStopSpinner(start: false)
                                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                                }
                            }
                        }
                    case .failure(_):
                        DispatchQueue.main.async {
                            self.startStopSpinner(start: false)
                            ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                        }
                    }
                }
            case .failure(_):
                DispatchQueue.main.async {
                    self.startStopSpinner(start: false)
                    ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error", titleButton: "Ok", over: self)
                }
            }
        }
    }
    
    private func setUpMarketModel(){
        
        self.linearValuesSP500.removeAll()
        self.linearValuesDJI .removeAll()
        self.linearValuesIXIC.removeAll()

        var centerLineData = [ChartDataEntry]()
        for index in 0...78 {
            centerLineData.append(ChartDataEntry(x: Double(index), y: 0.0))
        }
        let centerLine = LineChartDataSet(entries: centerLineData, label: "Center")
            
        for (index, candleValue) in self.marketsDataSP500.enumerated() {
            let closePrice = candleValue.close
            self.linearValuesSP500.append(ChartDataEntry(x: Double(index), y: closePrice))
        }
        let lineChartDataSetSP500 = LineChartDataSet(entries: linearValuesSP500, label: "SP500")
        
        for (index, candleValue) in self.marketsDataDJI.enumerated() {
            let closePrice = candleValue.close
            self.linearValuesDJI.append(ChartDataEntry(x: Double(index), y: closePrice))
        }
        let lineChartDataSetDJI = LineChartDataSet(entries: linearValuesDJI, label: "DJI")
        
        for (index, candleValue) in self.marketsDataIXIC.enumerated() {
            let closePrice = candleValue.close
            self.linearValuesIXIC.append(ChartDataEntry(x: Double(index), y: closePrice))
        }
        let lineChartDataSetIXIC = LineChartDataSet(entries: linearValuesIXIC, label: "NASDAQ")
        
        chartView.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.width(to: chartView)
        lineChartView.height(to: chartView)
        
        self.setData(centerLine: centerLine, lineChartSP500: lineChartDataSetSP500, lineChartDJI: lineChartDataSetDJI, lineChartIXIC: lineChartDataSetIXIC)
    }
    
    func setData(centerLine: LineChartDataSet, lineChartSP500: LineChartDataSet, lineChartDJI: LineChartDataSet, lineChartIXIC: LineChartDataSet) {
        let set0 = centerLine
        set0.mode = .linear
        set0.drawCirclesEnabled = false
        set0.lineWidth = 1
        set0.setColor(.label)
        set0.drawFilledEnabled = false
        set0.drawHorizontalHighlightIndicatorEnabled = true
        set0.drawVerticalHighlightIndicatorEnabled = false
        set0.highlightColor = .label
        
        let set1 = lineChartSP500
        set1.mode = .linear
        set1.drawCirclesEnabled = false
        set1.lineWidth = 2
        set1.setColor(.systemOrange)
        set1.drawFilledEnabled = false
        set1.drawHorizontalHighlightIndicatorEnabled = true
        set1.drawVerticalHighlightIndicatorEnabled = false
        set1.highlightColor = .label
        
        let set2 = lineChartDJI
        set2.mode = .linear
        set2.drawCirclesEnabled = false
        set2.lineWidth = 2
        set2.setColor(.systemBrown)
        set2.drawFilledEnabled = false
        set2.drawHorizontalHighlightIndicatorEnabled = true
        set2.drawVerticalHighlightIndicatorEnabled = false
        set2.highlightColor = .label

        let set3 = lineChartIXIC
        set3.mode = .linear
        set3.drawCirclesEnabled = false
        set3.lineWidth = 2
        set3.setColor(.systemBlue)
        set3.drawFilledEnabled = false
        set3.drawVerticalHighlightIndicatorEnabled = true
        set3.drawHorizontalHighlightIndicatorEnabled = false
        set3.highlightColor = .label
        
        let data = LineChartData(dataSets: [set0, set1, set2, set3])
        data.setDrawValues(false)
        lineChartView.data = data
    }
}



//MARK: Right top button in navigation controller
extension MarketsController {
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
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        imageViewTopRightButton.isUserInteractionEnabled = true
        imageViewTopRightButton.tintColor = .label
        imageViewTopRightButton.addGestureRecognizer(tapGestureRecognizer)
        
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewTopRightButton)
        //        imageView.layer.cornerRadius = Const.ImageSizeForLargeState / 2
        //        imageView.clipsToBounds = true
        imageViewTopRightButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageViewTopRightButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -ConstTopRightButton.ImageRightMargin),
            imageViewTopRightButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -ConstTopRightButton.ImageBottomMarginForLargeState),
            imageViewTopRightButton.heightAnchor.constraint(equalToConstant: ConstTopRightButton.ImageSizeForLargeState),
            imageViewTopRightButton.widthAnchor.constraint(equalTo: imageViewTopRightButton.heightAnchor)
        ])
    }
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        updateAllData()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
    }
    
    /// Show or hide the image from NavBar while going to next screen or back to initial screen
    /// - Parameter show: show or hide the image from NavBar
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageViewTopRightButton.alpha = show ? 1.0 : 0.0
        }
    }
}
