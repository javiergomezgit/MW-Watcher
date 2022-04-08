//
//  ChartController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/2/22.
//

import UIKit
import Charts
import TinyConstraints

class ChatController: UIViewController, ChartViewDelegate {
    
    private var cryptoData: [QuoteInvidual]?
    private var viewModels = [CryptosViewCellModel]()
    
    @IBOutlet weak var chartView: UIView!
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var selectChartButton: UIButton!
    
    @IBOutlet weak var currentPriceLabel: UILabel!
    @IBOutlet weak var currentPercentageLabel: UILabel!
    @IBOutlet weak var timeFrameSegmented: UISegmentedControl!
    @IBOutlet weak var nameLabel: UILabel!
    var selectedCandleChart = false
    
    var candleValues = [CandleChartDataEntry]()
    var linearValues = [ChartDataEntry]()

    
    @IBAction func timeFrameChange(_ sender: UISegmentedControl) {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadCryptoPrices()
    }
    
    private func loadCryptoPrices() {
        CryptosAPI.shared.getSelectedCrypto { [weak self] result in
            switch result {
            case .success(let data):
                
                self?.cryptoData = data
                print (data)
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

        guard let modelCandles = cryptoData else { return }


        
        //        let cryptosSortedByVolume = models.sorted { first, second -> Bool in
        //            return first.quote["USD"]!.volume_24h > second.quote["USD"]!.volume_24h
        //        }
       
        self.candleValues.removeAll()
        self.linearValues.removeAll()
        
        for candleValue in modelCandles {
                  let startingAt = candleValue.startingAt
            guard let openPrice = Double(candleValue.open) else { return }
            guard let highPrice = Double(candleValue.high) else { return }
            guard let closePrice = Double(candleValue.close) else { return }
            guard let lowPrice = Double(candleValue.low) else { return }
            
            let candleValueEntry = CandleChartDataEntry(x: Double(startingAt), shadowH: highPrice, shadowL: lowPrice, open: openPrice, close: closePrice)
            let linearValueEntry = ChartDataEntry(x: Double(startingAt), y: closePrice)
            
            self.candleValues.append(candleValueEntry)
            self.linearValues.append(linearValueEntry)
        }
        
        //self.candleValues = candleValuesTemp.sorted(by: { $0.low > $1.low })

        print (self.candleValues)
        self.choseTypeChart()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        print(entry)
    }
    
    @IBAction func selectTypeChart(_ sender: UIButton) {
        if selectedCandleChart {
            selectedCandleChart = false
        } else {
            selectedCandleChart = true
        }
        choseTypeChart()
    }
    
    func choseTypeChart(){
        if selectedCandleChart {
            lineChartView.removeFromSuperview()
            chartView.addSubview(candleView)
            candleView.centerInSuperview()
            candleView.width(to: chartView)
            candleView.height(to: chartView)
            
            selectChartButton.setImage(UIImage(named: "candles"), for: .normal)
            setDataCandleChart()
        } else {
            candleView.removeFromSuperview()
            chartView.addSubview(lineChartView)
            lineChartView.centerInSuperview()
            lineChartView.width(to: chartView)
            lineChartView.height(to: chartView)
            
            selectChartButton.setImage(UIImage(named: "chartline"), for: .normal)
            setDataLineChart()
        }
    }
    
    //MARK: Candle Chart
    lazy var candleView: CandleStickChartView = {
        let candleView = CandleStickChartView()
        candleView.delegate = self
        
        candleView.leftAxis.enabled = false
        candleView.xAxis.enabled = false
        candleView.rightAxis.enabled = true
        candleView.animate(xAxisDuration: 3.5)
        
        candleView.dragEnabled = false
        candleView.setScaleEnabled(true)
        candleView.maxVisibleCount = 50
        candleView.pinchZoomEnabled = false
        candleView.doubleTapToZoomEnabled = true
        candleView.dragXEnabled = true
        candleView.autoScaleMinMaxEnabled = true
  
        candleView.legend.enabled = false
//        candleView.legend.horizontalAlignment = .left
//        candleView.legend.verticalAlignment = .bottom
//        candleView.legend.orientation = .vertical
//        candleView.legend.drawInside = false
//        candleView.legend.font = UIFont(name: "HelveticaNeue-Light", size: 12)!
        candleView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        candleView.rightAxis.labelTextColor = .label
        candleView.rightAxis.spaceTop = 0.3
        candleView.rightAxis.spaceBottom = 0.3
        candleView.rightAxis.axisMinimum = 0
        
        return candleView
    }()
    
    func setDataCandleChart() {
        let set1 = CandleChartDataSet(entries: candleValues, label: "1 Hour Time Frame")
                
        set1.axisDependency = .left
        set1.setColor(UIColor(white: 80/255, alpha: 1))
       
        set1.drawHorizontalHighlightIndicatorEnabled = true
        set1.highlightColor = .systemGray
        set1.drawValuesEnabled = false
        set1.drawIconsEnabled = false
        set1.shadowColor = .label
        set1.shadowWidth = 1.1
        set1.decreasingColor = UIColor(named: "downtrend")!
        set1.decreasingFilled = true
        set1.increasingColor = UIColor(named: "uptrend")
        set1.increasingFilled = true
        
        let data = CandleChartData(dataSet: set1)
        candleView.data = data
    }
       
    
    //MARK: Linear Chart
    lazy var lineChartView: LineChartView = {
        let lineChartView = LineChartView()
        lineChartView.delegate = self
        lineChartView.leftAxis.enabled = false
        lineChartView.xAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        //lineChartView.animate(xAxisDuration: 0.2)
        
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.maxVisibleCount = 50
        lineChartView.pinchZoomEnabled = true

        lineChartView.legend.enabled = false
        
        lineChartView.rightAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size: 11)!
        lineChartView.rightAxis.labelTextColor = .label
        lineChartView.rightAxis.spaceTop = 0.3
        lineChartView.rightAxis.spaceBottom = 0.3
        lineChartView.rightAxis.axisMinimum = 0
        lineChartView.rightAxis.setLabelCount(10, force: false)
        lineChartView.rightAxis.axisLineColor = .label
        lineChartView.rightAxis.labelPosition = .outsideChart
        
        return lineChartView
    }()

    func setDataLineChart() {
        let set1 = LineChartDataSet(entries: linearValues, label: "Subscribs")
        
        set1.mode = .cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 1
        let v1 = linearValues.first!.y
        let v2 = linearValues.last!.y
        if v1 < v2 {
            set1.setColor(.blue.withAlphaComponent(0.2))
            set1.fill = Fill(color: .green)
            set1.fillAlpha = 0.7
        } else {
            set1.setColor(.red.withAlphaComponent(0.7))
            set1.fill = Fill(color: .red)
            set1.fillAlpha = 0.4
        }
        
        set1.drawFilledEnabled = true
        
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightColor = .systemRed
        
        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        lineChartView.data = data
    }
}









/*
 CandleChartDataEntry(x:1, shadowH:126.16, shadowL:123.07, open:123.87, close:125.90),
 CandleChartDataEntry(x:2, shadowH:127.13, shadowL:125.65, open:126.50, close:126.21),
 CandleChartDataEntry(x:3, shadowH:127.92, shadowL:125.14, open:125.83, close:127.90),
 CandleChartDataEntry(x:4, shadowH:130.39, shadowL:128.52, open:128.95, close:130.36),
 CandleChartDataEntry(x:5, shadowH:133.04, shadowL:129.47, open:129.80, close:133.00),
 CandleChartDataEntry(x:6, shadowH:132.85, shadowL:130.63, open:132.52, close:131.24),
 CandleChartDataEntry(x:7, shadowH:134.66, shadowL:131.93, open:132.44, close:134.43),
 CandleChartDataEntry(x:8, shadowH:135.00, shadowL:131.66, open:134.94, close:132.03),
 CandleChartDataEntry(x:9, shadowH:135.00, shadowL:133.64, open:133.82, close:134.50),
 CandleChartDataEntry(x:10, shadowH:134.67, shadowL:133.28, open:134.30, close:134.16),
 CandleChartDataEntry(x:11, shadowH:135.47, shadowL:133.34, open:133.51, close:134.84),
 CandleChartDataEntry(x:12, shadowH:135.53, shadowL:131.81, open:135.02, close:133.11),
 CandleChartDataEntry(x:13, shadowH:133.75, shadowL:131.30, open:132.36, close:133.50),
 CandleChartDataEntry(x:14, shadowH:134.15, shadowL:131.41, open:133.04, close:131.94),
 CandleChartDataEntry(x:15, shadowH:135.12, shadowL:132.16, open:132.16, close:134.32),
 CandleChartDataEntry(x:16, shadowH:135.06, shadowL:133.56, open:134.83, close:134.72),
 CandleChartDataEntry(x:17, shadowH:135.41, shadowL:134.11, open:135.01, close:134.39),
 CandleChartDataEntry(x:18, shadowH:135.02, shadowL:133.08, open:134.31, close:133.58),
 CandleChartDataEntry(x:19, shadowH:137.07, shadowL:132.45, open:136.47, close:133.48),
 CandleChartDataEntry(x:20, shadowH:133.56, shadowL:131.07, open:131.78, close:131.46),
 CandleChartDataEntry(x:21, shadowH:134.07, shadowL:131.83, open:132.04, close:132.54),
 CandleChartDataEntry(x:22, shadowH:131.49, shadowL:126.70, open:131.19, close:127.85),
 CandleChartDataEntry(x:23, shadowH:130.45, shadowL:127.97, open:129.20, close:128.10),
 CandleChartDataEntry(x:24, shadowH:129.75, shadowL:127.13, open:127.89, close:129.74),
 CandleChartDataEntry(x:25, shadowH:131.26, shadowL:129.48, open:130.85, close:130.21),
 CandleChartDataEntry(x:26, shadowH:129.54, shadowL:126.81, open:129.41, close:126.85),
 CandleChartDataEntry(x:27, shadowH:126.27, shadowL:122.77, open:123.50, close:125.91),
 CandleChartDataEntry(x:28, shadowH:124.64, shadowL:122.25, open:123.40, close:122.77),
 CandleChartDataEntry(x:29, shadowH:126.15, shadowL:124.26, open:124.58, close:124.97),
 CandleChartDataEntry(x:30, shadowH:127.89, shadowL:125.85, open:126.25, close:127.45),
 CandleChartDataEntry(x:31, shadowH:126.93, shadowL:125.17, open:126.82, close:126.27),
 CandleChartDataEntry(x:32, shadowH:126.99, shadowL:124.78, open:126.56, close:124.85),
 CandleChartDataEntry(x:33, shadowH:124.92, shadowL:122.86, open:123.16, close:124.69),
 CandleChartDataEntry(x:34, shadowH:127.72, shadowL:125.10, open:125.23, close:127.31),
 CandleChartDataEntry(x:35, shadowH:128.00, shadowL:125.21, open:127.82, close:125.43),
 CandleChartDataEntry(x:36, shadowH:127.94, shadowL:125.94, open:126.01, close:127.10),
 CandleChartDataEntry(x:37, shadowH:128.32, shadowL:126.32, open:127.82, close:126.90),
 CandleChartDataEntry(x:38, shadowH:127.39, shadowL:126.42, open:126.96, close:126.85),
 CandleChartDataEntry(x:39, shadowH:127.64, shadowL:125.08, open:126.44, close:125.28),
 CandleChartDataEntry(x:40, shadowH:125.80, shadowL:124.55, open:125.57, close:124.61),
 CandleChartDataEntry(x:41, shadowH:125.35, shadowL:123.94, open:125.08, close:124.28),
 CandleChartDataEntry(x:42, shadowH:125.24, shadowL:124.05, open:124.28, close:125.06),
 CandleChartDataEntry(x:43, shadowH:124.85, shadowL:123.13, open:124.68, close:123.54),
 CandleChartDataEntry(x:44, shadowH:126.16, shadowL:123.85, open:124.07, close:125.89),
 CandleChartDataEntry(x:45, shadowH:126.32, shadowL:124.83, open:126.17, close:125.90),
 CandleChartDataEntry(x:46, shadowH:128.46, shadowL:126.21, open:126.60, close:126.74),
 CandleChartDataEntry(x:47, shadowH:127.75, shadowL:126.52, open:127.21, close:127.13),
 CandleChartDataEntry(x:48, shadowH:128.19, shadowL:125.94, open:127.02, close:126.11),
 CandleChartDataEntry(x:49, shadowH:127.44, shadowL:126.10, open:126.53, close:127.35),
 CandleChartDataEntry(x:50, shadowH:130.54, shadowL:127.07, open:127.82, close:130.48),
 CandleChartDataEntry(x:51, shadowH:130.60, shadowL:129.39, open:129.94, close:129.64),
 CandleChartDataEntry(x:52, shadowH:130.89, shadowL:128.46, open:130.37, close:130.15),
 CandleChartDataEntry(x:53, shadowH:132.55, shadowL:129.65, open:129.80, close:131.79),
 CandleChartDataEntry(x:54, shadowH:131.51, shadowL:130.24, open:130.71, close:130.46),
 CandleChartDataEntry(x:55, shadowH:132.41, shadowL:129.21, open:130.30, close:132.30),
 CandleChartDataEntry(x:56, shadowH:134.08, shadowL:131.62, open:132.13, close:133.98),
 CandleChartDataEntry(x:57, shadowH:134.32, shadowL:133.23, open:133.77, close:133.70),
 CandleChartDataEntry(x:58, shadowH:134.64, shadowL:132.93, open:134.45, close:133.41),
 CandleChartDataEntry(x:59, shadowH:133.89, shadowL:132.81, open:133.46, close:133.11),
 CandleChartDataEntry(x:60, shadowH:135.25, shadowL:133.35, open:133.41, close:134.78),
 CandleChartDataEntry(x:61, shadowH:136.49, shadowL:134.35, open:134.80, close:136.33),
 CandleChartDataEntry(x:62, shadowH:137.41, shadowL:135.87, open:136.17, close:136.96),
 CandleChartDataEntry(x:63, shadowH:137.33, shadowL:135.76, open:136.60, close:137.27),
 CandleChartDataEntry(x:64, shadowH:140.00, shadowL:137.75, open:137.90, close:139.96),
 CandleChartDataEntry(x:65, shadowH:143.15, shadowL:140.07, open:140.07, close:142.02),
 CandleChartDataEntry(x:66, shadowH:144.89, shadowL:142.66, open:143.54, close:144.57),
 CandleChartDataEntry(x:67, shadowH:144.06, shadowL:140.67, open:141.58, close:143.24),
 CandleChartDataEntry(x:68, shadowH:145.65, shadowL:142.65, open:142.75, close:145.11),
 CandleChartDataEntry(x:69, shadowH:146.32, shadowL:144.00, open:146.21, close:144.50),
 CandleChartDataEntry(x:70, shadowH:147.46, shadowL:143.63, open:144.03, close:145.64),
 CandleChartDataEntry(x:71, shadowH:149.57, shadowL:147.68, open:148.10, close:149.15),
 CandleChartDataEntry(x:72, shadowH:150.00, shadowL:147.09, open:149.24, close:148.48),
 CandleChartDataEntry(x:73, shadowH:149.76, shadowL:145.88, open:148.46, close:146.39),
 CandleChartDataEntry(x:74, shadowH:144.07, shadowL:141.67, open:143.75, close:142.45),
 CandleChartDataEntry(x:75, shadowH:147.10, shadowL:142.96, open:143.46, close:146.15),
 CandleChartDataEntry(x:76, shadowH:146.13, shadowL:144.63, open:145.53, close:145.40),
 CandleChartDataEntry(x:77, shadowH:148.20, shadowL:145.81, open:145.94, close:146.80),
 CandleChartDataEntry(x:78, shadowH:148.72, shadowL:146.92, open:147.55, close:148.56),
 CandleChartDataEntry(x:79, shadowH:149.83, shadowL:147.70, open:148.27, close:148.99),
 CandleChartDataEntry(x:80, shadowH:149.21, shadowL:145.55, open:149.12, close:146.77),
 CandleChartDataEntry(x:81, shadowH:146.97, shadowL:142.54, open:144.81, close:144.98),
 CandleChartDataEntry(x:82, shadowH:146.55, shadowL:144.58, open:144.69, close:145.64),
 CandleChartDataEntry(x:83, shadowH:146.33, shadowL:144.11, open:144.38, close:145.86),
 CandleChartDataEntry(x:84, shadowH:146.95, shadowL:145.25, open:146.36, close:145.52),
 CandleChartDataEntry(x:85, shadowH:148.04, shadowL:145.18, open:145.81, close:147.36),
 CandleChartDataEntry(x:86, shadowH:147.79, shadowL:146.28, open:147.27, close:146.95),
 CandleChartDataEntry(x:87, shadowH:147.84, shadowL:146.17, open:146.98, close:147.06),
 CandleChartDataEntry(x:88, shadowH:147.11, shadowL:145.63, open:146.35, close:146.14),
 CandleChartDataEntry(x:89, shadowH:146.70, shadowL:145.52, open:146.20, close:146.09),
 CandleChartDataEntry(x:90, shadowH:147.71, shadowL:145.30, open:146.44, close:145.60),
 CandleChartDataEntry(x:91, shadowH:146.72, shadowL:145.53, open:146.05, close:145.86),
 CandleChartDataEntry(x:92, shadowH:149.05, shadowL:145.84, open:146.19, close:148.89),
 CandleChartDataEntry(x:93, shadowH:149.44, shadowL:148.27, open:148.97, close:149.10),
 CandleChartDataEntry(x:94, shadowH:151.19, shadowL:146.47, open:148.54, close:151.12),
 CandleChartDataEntry(x:95, shadowH:151.68, shadowL:149.09, open:150.23, close:150.19),
 CandleChartDataEntry(x:96, shadowH:150.72, shadowL:146.15, open:149.80, close:146.36),
 CandleChartDataEntry(x:97, shadowH:148.00, shadowL:144.50, open:145.03, close:146.70),
 CandleChartDataEntry(x:98, shadowH:148.50, shadowL:146.78, open:147.44, close:148.19),
 CandleChartDataEntry(x:99, shadowH:150.19, shadowL:147.89, open:148.31, close:149.71),
 CandleChartDataEntry(x:100, shadowH:150.86, shadowL:149.15, open:149.45, close:149.62),
 CandleChartDataEntry(x:101, shadowH:150.32, shadowL:147.80, open:149.81, close:148.36),
 CandleChartDataEntry(x:102, shadowH:149.12, shadowL:147.51, open:148.35, close:147.54),
 CandleChartDataEntry(x:103, shadowH:148.75, shadowL:146.83, open:147.48, close:148.60),
 CandleChartDataEntry(x:104, shadowH:153.49, shadowL:148.61, open:149.00, close:153.12),
 CandleChartDataEntry(x:105, shadowH:152.80, shadowL:151.29, open:152.66, close:151.83),
 CandleChartDataEntry(x:106, shadowH:154.98, shadowL:152.34, open:152.83, close:152.51),
 CandleChartDataEntry(x:107, shadowH:154.72, shadowL:152.40, open:153.87, close:153.65),
 CandleChartDataEntry(x:108, shadowH:154.63, shadowL:153.09, open:153.76, close:154.30),
 CandleChartDataEntry(x:109, shadowH:157.26, shadowL:154.39, open:154.97, close:156.69),
 CandleChartDataEntry(x:110, shadowH:157.04, shadowL:153.98, open:156.98, close:155.11),
 CandleChartDataEntry(x:111, shadowH:156.11, shadowL:153.95, open:155.49, close:154.07),
 CandleChartDataEntry(x:112, shadowH:155.48, shadowL:148.70, open:155.00, close:148.97),
 CandleChartDataEntry(x:113, shadowH:151.42, shadowL:148.75, open:150.63, close:149.55),
 CandleChartDataEntry(x:114, shadowH:151.07, shadowL:146.91, open:150.35, close:148.12),
 CandleChartDataEntry(x:115, shadowH:149.44, shadowL:146.37, open:148.56, close:149.03),
 CandleChartDataEntry(x:116, shadowH:148.97, shadowL:147.22, open:148.44, close:148.79),
 CandleChartDataEntry(x:117, shadowH:148.82, shadowL:145.76, open:148.82, close:146.06),
 CandleChartDataEntry(x:118, shadowH:144.84, shadowL:141.27, open:143.80, close:142.94),
 CandleChartDataEntry(x:119, shadowH:144.60, shadowL:142.78, open:143.93, close:143.43),
 CandleChartDataEntry(x:120, shadowH:146.43, shadowL:143.70, open:144.45, close:145.85),
 CandleChartDataEntry(x:121, shadowH:147.08, shadowL:145.64, open:146.65, close:146.83),
 CandleChartDataEntry(x:122, shadowH:147.47, shadowL:145.56, open:145.66, close:146.92),
 CandleChartDataEntry(x:123, shadowH:145.96, shadowL:143.82, open:145.47, close:145.37),
 CandleChartDataEntry(x:124, shadowH:144.75, shadowL:141.69, open:143.25, close:141.91),
 CandleChartDataEntry(x:125, shadowH:144.45, shadowL:142.03, open:142.47, close:142.83),
 CandleChartDataEntry(x:126, shadowH:144.38, shadowL:141.28, open:143.66, close:141.50),
 CandleChartDataEntry(x:127, shadowH:142.92, shadowL:139.11, open:141.90, close:142.65),
 CandleChartDataEntry(x:128, shadowH:142.21, shadowL:138.27, open:141.76, close:139.14),
 CandleChartDataEntry(x:129, shadowH:142.24, shadowL:139.36, open:139.49, close:141.11),
 CandleChartDataEntry(x:130, shadowH:142.15, shadowL:138.37, open:139.47, close:142.00),
 CandleChartDataEntry(x:131, shadowH:144.22, shadowL:142.72, open:143.06, close:143.29),
 CandleChartDataEntry(x:132, shadowH:144.18, shadowL:142.56, open:144.03, close:142.90),
 CandleChartDataEntry(x:133, shadowH:144.81, shadowL:141.81, open:142.27, close:142.81),
 CandleChartDataEntry(x:134, shadowH:143.25, shadowL:141.04, open:143.23, close:141.51),
 CandleChartDataEntry(x:135, shadowH:141.40, shadowL:139.20, open:141.24, close:140.91),
 CandleChartDataEntry(x:136, shadowH:143.88, shadowL:141.51, open:142.11, close:143.76),
 CandleChartDataEntry(x:137, shadowH:144.90, shadowL:143.51, open:143.77, close:144.84),
 CandleChartDataEntry(x:138, shadowH:146.84, shadowL:143.16, open:143.45, close:146.55),
 CandleChartDataEntry(x:139, shadowH:149.17, shadowL:146.55, open:147.01, close:148.76),
 CandleChartDataEntry(x:140, shadowH:149.75, shadowL:148.12, open:148.70, close:149.26),
 CandleChartDataEntry(x:141, shadowH:149.64, shadowL:147.87, open:148.81, close:149.48),
 CandleChartDataEntry(x:142, shadowH:150.18, shadowL:148.64, open:149.69, close:148.69),
 CandleChartDataEntry(x:143, shadowH:149.37, shadowL:147.62, open:148.68, close:148.64),
 CandleChartDataEntry(x:144, shadowH:150.84, shadowL:149.01, open:149.33, close:149.32),
 CandleChartDataEntry(x:145, shadowH:149.73, shadowL:148.49, open:149.36, close:148.85),
 CandleChartDataEntry(x:146, shadowH:153.17, shadowL:149.72, open:149.82, close:152.57),
 CandleChartDataEntry(x:147, shadowH:149.94, shadowL:146.41, open:147.22, close:149.80),
 CandleChartDataEntry(x:148, shadowH:149.70, shadowL:147.80, open:148.99, close:148.96),
 CandleChartDataEntry(x:149, shadowH:151.57, shadowL:148.65, open:148.66, close:150.02),
 CandleChartDataEntry(x:150, shadowH:151.97, shadowL:149.82, open:150.39, close:151.49),
 CandleChartDataEntry(x:151, shadowH:152.43, shadowL:150.64, open:151.58, close:150.96),
 CandleChartDataEntry(x:152, shadowH:152.20, shadowL:150.06, open:151.89, close:151.28),
 CandleChartDataEntry(x:153, shadowH:151.57, shadowL:150.16, open:151.41, close:150.44),
 CandleChartDataEntry(x:154, shadowH:151.43, shadowL:150.06, open:150.20, close:150.81),
 CandleChartDataEntry(x:155, shadowH:150.13, shadowL:147.85, open:150.02, close:147.92),
 CandleChartDataEntry(x:156, shadowH:149.43, shadowL:147.68, open:148.96, close:147.87),
 CandleChartDataEntry(x:157, shadowH:150.40, shadowL:147.48, open:148.43, close:149.99),
 CandleChartDataEntry(x:158, shadowH:151.88, shadowL:149.43, open:150.37, close:150.00),
 CandleChartDataEntry(x:159, shadowH:151.49, shadowL:149.34, open:149.94, close:151.00),
 CandleChartDataEntry(x:160, shadowH:155.00, shadowL:150.99, open:151.00, close:153.49),
 CandleChartDataEntry(x:161, shadowH:158.67, shadowL:153.05, open:153.71, close:157.87),
 CandleChartDataEntry(x:162, shadowH:161.02, shadowL:156.53, open:157.65, close:160.55),
 CandleChartDataEntry(x:163, shadowH:165.70, shadowL:161.00, open:161.68, close:161.02),
 CandleChartDataEntry(x:164, shadowH:161.80, shadowL:159.06, open:161.12, close:161.41),
 CandleChartDataEntry(x:165, shadowH:162.14, shadowL:159.64, open:160.75, close:161.94),
 CandleChartDataEntry(x:166, shadowH:160.45, shadowL:156.36, open:159.57, close:156.81),
 CandleChartDataEntry(x:167, shadowH:161.19, shadowL:158.79, open:159.37, close:160.24),
 CandleChartDataEntry(x:168, shadowH:165.52, shadowL:159.92, open:159.99, close:165.30),
 CandleChartDataEntry(x:169, shadowH:170.30, shadowL:164.53, open:167.48, close:164.77),
 CandleChartDataEntry(x:170, shadowH:164.20, shadowL:157.80, open:158.74, close:163.76),
 CandleChartDataEntry(x:171, shadowH:164.96, shadowL:159.72, open:164.02, close:161.84),
 CandleChartDataEntry(x:172, shadowH:167.88, shadowL:164.28, open:164.29, close:165.32),
 CandleChartDataEntry(x:173, shadowH:171.58, shadowL:168.34, open:169.08, close:171.18),
 CandleChartDataEntry(x:174, shadowH:175.96, shadowL:170.70, open:172.13, close:175.08),
 CandleChartDataEntry(x:175, shadowH:176.75, shadowL:173.92, open:174.91, close:174.56),
 CandleChartDataEntry(x:176, shadowH:179.63, shadowL:174.69, open:175.21, close:179.45),
 CandleChartDataEntry(x:177, shadowH:182.13, shadowL:175.53, open:181.12, close:175.74),
 CandleChartDataEntry(x:178, shadowH:177.74, shadowL:172.21, open:175.25, close:174.33),
 CandleChartDataEntry(x:179, shadowH:179.50, shadowL:172.31, open:175.11, close:179.30),
 CandleChartDataEntry(x:180, shadowH:181.14, shadowL:170.75, open:179.28, close:172.26),
 CandleChartDataEntry(x:181, shadowH:173.47, shadowL:169.69, open:169.93, close:171.14),
 CandleChartDataEntry(x:182, shadowH:170.58, shadowL:167.46, open:168.28, close:169.75),
 CandleChartDataEntry(x:183, shadowH:173.20, shadowL:169.12, open:171.56, close:172.99),
 CandleChartDataEntry(x:184, shadowH:175.86, shadowL:172.15, open:173.04, close:175.64),
 CandleChartDataEntry(x:185, shadowH:176.85, shadowL:175.27, open:175.85, close:176.28),
 CandleChartDataEntry(x:186, shadowH:180.42, shadowL:177.07, open:177.09, close:180.33),
 CandleChartDataEntry(x:187, shadowH:181.33, shadowL:178.53, open:180.16, close:179.29),
 CandleChartDataEntry(x:188, shadowH:180.63, shadowL:178.14, open:179.33, close:179.38),
 CandleChartDataEntry(x:189, shadowH:180.57, shadowL:178.09, open:179.47, close:178.20),
 CandleChartDataEntry(x:190, shadowH:179.23, shadowL:177.26, open:178.09, close:177.57),
 CandleChartDataEntry(x:191, shadowH:182.88, shadowL:177.71, open:177.83, close:182.01),
 CandleChartDataEntry(x:192, shadowH:182.94, shadowL:179.12, open:182.63, close:179.70),
 CandleChartDataEntry(x:193, shadowH:180.17, shadowL:174.64, open:179.61, close:174.92),
 CandleChartDataEntry(x:194, shadowH:175.30, shadowL:171.64, open:172.70, close:172.00),
 CandleChartDataEntry(x:195, shadowH:174.14, shadowL:171.03, open:172.89, close:172.17),
 CandleChartDataEntry(x:196, shadowH:172.50, shadowL:168.17, open:169.08, close:172.19),
 CandleChartDataEntry(x:197, shadowH:175.18, shadowL:170.82, open:172.32, close:175.08),
 CandleChartDataEntry(x:198, shadowH:177.18, shadowL:174.82, open:176.12, close:175.53),
 CandleChartDataEntry(x:199, shadowH:176.62, shadowL:171.79, open:175.78, close:172.19),
 CandleChartDataEntry(x:200, shadowH:173.78, shadowL:171.09, open:171.34, close:173.07),
 CandleChartDataEntry(x:201, shadowH:172.54, shadowL:169.41, open:171.51, close:169.80),
 CandleChartDataEntry(x:202, shadowH:171.08, shadowL:165.94, open:170.00, close:166.23),
 CandleChartDataEntry(x:203, shadowH:169.68, shadowL:164.18, open:166.98, close:164.51),
 CandleChartDataEntry(x:204, shadowH:166.33, shadowL:162.30, open:164.42, close:162.41),
 CandleChartDataEntry(x:205, shadowH:162.30, shadowL:154.70, open:160.02, close:161.62),
 CandleChartDataEntry(x:206, shadowH:162.76, shadowL:157.02, open:158.98, close:159.78),
 CandleChartDataEntry(x:207, shadowH:164.39, shadowL:157.82, open:163.50, close:159.69),
 CandleChartDataEntry(x:208, shadowH:163.84, shadowL:158.28, open:162.45, close:159.22),
 CandleChartDataEntry(x:209, shadowH:170.35, shadowL:162.80, open:165.71, close:170.33),
 CandleChartDataEntry(x:210, shadowH:175.00, shadowL:169.51, open:170.16, close:174.78),
 CandleChartDataEntry(x:211, shadowH:174.84, shadowL:172.31, open:174.01, close:174.61),
 CandleChartDataEntry(x:212, shadowH:175.88, shadowL:173.33, open:174.75, close:175.84),
 CandleChartDataEntry(x:213, shadowH:176.24, shadowL:172.12, open:174.48, close:172.90),
 CandleChartDataEntry(x:214, shadowH:174.10, shadowL:170.68, open:171.68, close:172.39),
 CandleChartDataEntry(x:215, shadowH:173.95, shadowL:170.95, open:172.86, close:171.66),
 CandleChartDataEntry(x:216, shadowH:175.35, shadowL:171.43, open:171.73, close:174.83),
 CandleChartDataEntry(x:217, shadowH:176.65, shadowL:174.90, open:176.05, close:176.28),
 CandleChartDataEntry(x:218, shadowH:175.48, shadowL:171.55, open:174.14, close:172.12),
 CandleChartDataEntry(x:219, shadowH:173.08, shadowL:168.04, open:172.33, close:168.64),
 CandleChartDataEntry(x:220, shadowH:169.58, shadowL:166.56, open:167.37, close:168.88),
 CandleChartDataEntry(x:221, shadowH:172.95, shadowL:170.25, open:170.97, close:172.79),
 CandleChartDataEntry(x:222, shadowH:173.34, shadowL:170.05, open:171.85, close:172.55),
 CandleChartDataEntry(x:223, shadowH:171.91, shadowL:168.47, open:171.03, close:168.88),
 CandleChartDataEntry(x:224, shadowH:170.54, shadowL:166.19, open:169.82, close:167.30),
 CandleChartDataEntry(x:225, shadowH:166.69, shadowL:162.15, open:164.98, close:164.32),
 CandleChartDataEntry(x:226, shadowH:166.15, shadowL:159.75, open:165.54, close:160.07),
 CandleChartDataEntry(x:227, shadowH:162.85, shadowL:152.00, open:152.58, close:162.74),
 CandleChartDataEntry(x:228, shadowH:165.12, shadowL:160.87, open:163.84, close:164.85),
 CandleChartDataEntry(x:229, shadowH:165.42, shadowL:162.43, open:163.06, close:165.12),
 CandleChartDataEntry(x:230, shadowH:166.60, shadowL:161.97, open:164.70, close:163.20),
 CandleChartDataEntry(x:231, shadowH:167.36, shadowL:162.95, open:164.39, close:166.56),
 CandleChartDataEntry(x:232, shadowH:168.91, shadowL:165.55, open:168.47, close:166.23),
 CandleChartDataEntry(x:233, shadowH:165.55, shadowL:162.10, open:164.49, close:163.17),
 CandleChartDataEntry(x:234, shadowH:165.02, shadowL:159.04, open:163.36, close:159.30),
 CandleChartDataEntry(x:235, shadowH:162.88, shadowL:155.80, open:158.82, close:157.44),
 CandleChartDataEntry(x:236, shadowH:163.41, shadowL:159.41, open:161.48, close:162.95),
 CandleChartDataEntry(x:237, shadowH:160.39, shadowL:155.98, open:160.20, close:158.52),
 CandleChartDataEntry(x:238, shadowH:159.28, shadowL:154.50, open:158.93, close:154.73),
 CandleChartDataEntry(x:239, shadowH:154.12, shadowL:150.10, open:151.45, close:150.62),
 CandleChartDataEntry(x:240, shadowH:155.57, shadowL:150.38, open:150.90, close:155.09),
 CandleChartDataEntry(x:241, shadowH:160.00, shadowL:154.46, open:157.05, close:159.59),
 CandleChartDataEntry(x:242, shadowH:161.00, shadowL:157.63, open:158.61, close:160.62),
 CandleChartDataEntry(x:243, shadowH:164.48, shadowL:159.76, open:160.51, close:163.98),
 CandleChartDataEntry(x:244, shadowH:166.35, shadowL:163.01, open:163.51, close:165.38),
 CandleChartDataEntry(x:245, shadowH:169.42, shadowL:164.91, open:165.51, close:168.82),
 CandleChartDataEntry(x:246, shadowH:172.64, shadowL:167.65, open:167.99, close:170.21),
 CandleChartDataEntry(x:247, shadowH:174.14, shadowL:170.21, open:171.06, close:174.07),
 CandleChartDataEntry(x:248, shadowH:175.28, shadowL:172.75, open:173.88, close:174.72),
 CandleChartDataEntry(x:249, shadowH:175.73, shadowL:172.00, open:172.17, close:175.60),
 CandleChartDataEntry(x:250, shadowH:179.01, shadowL:176.34, open:176.69, close:178.96),
 CandleChartDataEntry(x:251, shadowH:179.61, shadowL:176.70, open:178.55, close:177.77),
 CandleChartDataEntry(x:252, shadowH:178.03, shadowL:174.40, open:177.84, close:174.61),
 CandleChartDataEntry(x:253, shadowH:174.88, shadowL:171.94, open:174.03, close:174.31),
 CandleChartDataEntry(x:254, shadowH:178.49, shadowL:174.44, open:174.57, close:178.44),
 CandleChartDataEntry(x:255, shadowH:178.30, shadowL:174.42, open:177.50, close:175.06)
 
 
 ChartDataEntry(x:0, y:124.89),
 ChartDataEntry(x:1, y:126.35),
 ChartDataEntry(x:2, y:126.87),
 ChartDataEntry(x:3, y:129.65),
 ChartDataEntry(x:4, y:131.40),
 ChartDataEntry(x:5, y:131.88),
 ChartDataEntry(x:6, y:133.43),
 ChartDataEntry(x:7, y:133.49),
 ChartDataEntry(x:8, y:134.16),
 ChartDataEntry(x:9, y:134.23),
 ChartDataEntry(x:10, y:134.17),
 ChartDataEntry(x:11, y:134.07),
 ChartDataEntry(x:12, y:132.93),
 ChartDataEntry(x:13, y:132.49),
 ChartDataEntry(x:14, y:133.24),
 ChartDataEntry(x:15, y:134.78),
 ChartDataEntry(x:16, y:134.70),
 ChartDataEntry(x:17, y:133.95),
 ChartDataEntry(x:18, y:134.97),
 ChartDataEntry(x:19, y:131.62),
 ChartDataEntry(x:20, y:132.29),
 ChartDataEntry(x:21, y:129.52),
 ChartDataEntry(x:22, y:128.65),
 ChartDataEntry(x:23, y:128.82),
 ChartDataEntry(x:24, y:130.53),
 ChartDataEntry(x:25, y:128.13),
 ChartDataEntry(x:26, y:124.71),
 ChartDataEntry(x:27, y:123.08),
 ChartDataEntry(x:28, y:124.78),
 ChartDataEntry(x:29, y:126.85),
 ChartDataEntry(x:30, y:126.54),
 ChartDataEntry(x:31, y:125.70),
 ChartDataEntry(x:32, y:123.93),
 ChartDataEntry(x:33, y:126.27),
 ChartDataEntry(x:34, y:126.63),
 ChartDataEntry(x:35, y:126.56),
 ChartDataEntry(x:36, y:127.36),
 ChartDataEntry(x:37, y:126.90),
 ChartDataEntry(x:38, y:125.86),
 ChartDataEntry(x:39, y:125.09),
 ChartDataEntry(x:40, y:124.68),
 ChartDataEntry(x:41, y:124.67),
 ChartDataEntry(x:42, y:124.11),
 ChartDataEntry(x:43, y:124.98),
 ChartDataEntry(x:44, y:126.04),
 ChartDataEntry(x:45, y:126.67),
 ChartDataEntry(x:46, y:127.17),
 ChartDataEntry(x:47, y:126.56),
 ChartDataEntry(x:48, y:126.94),
 ChartDataEntry(x:49, y:129.15),
 ChartDataEntry(x:50, y:129.79),
 ChartDataEntry(x:51, y:130.26),
 ChartDataEntry(x:52, y:130.79),
 ChartDataEntry(x:53, y:130.59),
 ChartDataEntry(x:54, y:131.30),
 ChartDataEntry(x:55, y:133.06),
 ChartDataEntry(x:56, y:133.74),
 ChartDataEntry(x:57, y:133.93),
 ChartDataEntry(x:58, y:133.29),
 ChartDataEntry(x:59, y:134.10),
 ChartDataEntry(x:60, y:135.57),
 ChartDataEntry(x:61, y:136.57),
 ChartDataEntry(x:62, y:136.94),
 ChartDataEntry(x:63, y:138.93),
 ChartDataEntry(x:64, y:141.05),
 ChartDataEntry(x:65, y:144.06),
 ChartDataEntry(x:66, y:142.41),
 ChartDataEntry(x:67, y:143.93),
 ChartDataEntry(x:68, y:145.36),
 ChartDataEntry(x:69, y:144.83),
 ChartDataEntry(x:70, y:148.63),
 ChartDataEntry(x:71, y:148.86),
 ChartDataEntry(x:72, y:147.43),
 ChartDataEntry(x:73, y:143.10),
 ChartDataEntry(x:74, y:144.81),
 ChartDataEntry(x:75, y:145.46),
 ChartDataEntry(x:76, y:146.37),
 ChartDataEntry(x:77, y:148.06),
 ChartDataEntry(x:78, y:148.63),
 ChartDataEntry(x:79, y:147.94),
 ChartDataEntry(x:80, y:144.89),
 ChartDataEntry(x:81, y:145.17),
 ChartDataEntry(x:82, y:145.12),
 ChartDataEntry(x:83, y:145.94),
 ChartDataEntry(x:84, y:146.58),
 ChartDataEntry(x:85, y:147.11),
 ChartDataEntry(x:86, y:147.02),
 ChartDataEntry(x:87, y:146.25),
 ChartDataEntry(x:88, y:146.14),
 ChartDataEntry(x:89, y:146.02),
 ChartDataEntry(x:90, y:145.96),
 ChartDataEntry(x:91, y:147.54),
 ChartDataEntry(x:92, y:149.04),
 ChartDataEntry(x:93, y:149.83),
 ChartDataEntry(x:94, y:150.21),
 ChartDataEntry(x:95, y:148.08),
 ChartDataEntry(x:96, y:145.86),
 ChartDataEntry(x:97, y:147.82),
 ChartDataEntry(x:98, y:149.01),
 ChartDataEntry(x:99, y:149.53),
 ChartDataEntry(x:100, y:149.08),
 ChartDataEntry(x:101, y:147.94),
 ChartDataEntry(x:102, y:148.04),
 ChartDataEntry(x:103, y:151.06),
 ChartDataEntry(x:104, y:152.25),
 ChartDataEntry(x:105, y:152.67),
 ChartDataEntry(x:106, y:153.76),
 ChartDataEntry(x:107, y:154.03),
 ChartDataEntry(x:108, y:155.83),
 ChartDataEntry(x:109, y:156.04),
 ChartDataEntry(x:110, y:154.78),
 ChartDataEntry(x:111, y:151.99),
 ChartDataEntry(x:112, y:150.09),
 ChartDataEntry(x:113, y:149.24),
 ChartDataEntry(x:114, y:148.79),
 ChartDataEntry(x:115, y:148.61),
 ChartDataEntry(x:116, y:147.44),
 ChartDataEntry(x:117, y:143.37),
 ChartDataEntry(x:118, y:143.68),
 ChartDataEntry(x:119, y:145.15),
 ChartDataEntry(x:120, y:146.74),
 ChartDataEntry(x:121, y:146.29),
 ChartDataEntry(x:122, y:145.42),
 ChartDataEntry(x:123, y:142.58),
 ChartDataEntry(x:124, y:142.65),
 ChartDataEntry(x:125, y:142.58),
 ChartDataEntry(x:126, y:142.27),
 ChartDataEntry(x:127, y:140.45),
 ChartDataEntry(x:128, y:140.30),
 ChartDataEntry(x:129, y:140.74),
 ChartDataEntry(x:130, y:143.17),
 ChartDataEntry(x:131, y:143.46),
 ChartDataEntry(x:132, y:142.54),
 ChartDataEntry(x:133, y:142.37),
 ChartDataEntry(x:134, y:141.08),
 ChartDataEntry(x:135, y:142.93),
 ChartDataEntry(x:136, y:144.31),
 ChartDataEntry(x:137, y:145.00),
 ChartDataEntry(x:138, y:147.88),
 ChartDataEntry(x:139, y:148.98),
 ChartDataEntry(x:140, y:149.14),
 ChartDataEntry(x:141, y:149.19),
 ChartDataEntry(x:142, y:148.66),
 ChartDataEntry(x:143, y:149.33),
 ChartDataEntry(x:144, y:149.11),
 ChartDataEntry(x:145, y:151.20),
 ChartDataEntry(x:146, y:148.51),
 ChartDataEntry(x:147, y:148.98),
 ChartDataEntry(x:148, y:149.34),
 ChartDataEntry(x:149, y:150.94),
 ChartDataEntry(x:150, y:151.27),
 ChartDataEntry(x:151, y:151.58),
 ChartDataEntry(x:152, y:150.93),
 ChartDataEntry(x:153, y:150.50),
 ChartDataEntry(x:154, y:148.97),
 ChartDataEntry(x:155, y:148.42),
 ChartDataEntry(x:156, y:149.21),
 ChartDataEntry(x:157, y:150.18),
 ChartDataEntry(x:158, y:150.47),
 ChartDataEntry(x:159, y:152.25),
 ChartDataEntry(x:160, y:155.79),
 ChartDataEntry(x:161, y:159.10),
 ChartDataEntry(x:162, y:161.35),
 ChartDataEntry(x:163, y:161.26),
 ChartDataEntry(x:164, y:161.35),
 ChartDataEntry(x:165, y:158.19),
 ChartDataEntry(x:166, y:159.81),
 ChartDataEntry(x:167, y:162.65),
 ChartDataEntry(x:168, y:166.13),
 ChartDataEntry(x:169, y:161.25),
 ChartDataEntry(x:170, y:162.93),
 ChartDataEntry(x:171, y:164.81),
 ChartDataEntry(x:172, y:170.13),
 ChartDataEntry(x:173, y:173.61),
 ChartDataEntry(x:174, y:174.74),
 ChartDataEntry(x:175, y:177.33),
 ChartDataEntry(x:176, y:178.43),
 ChartDataEntry(x:177, y:174.79),
 ChartDataEntry(x:178, y:177.21),
 ChartDataEntry(x:179, y:175.77),
 ChartDataEntry(x:180, y:170.53),
 ChartDataEntry(x:181, y:169.01),
 ChartDataEntry(x:182, y:172.28),
 ChartDataEntry(x:183, y:174.34),
 ChartDataEntry(x:184, y:176.07),
 ChartDataEntry(x:185, y:178.71),
 ChartDataEntry(x:186, y:179.72),
 ChartDataEntry(x:187, y:179.36),
 ChartDataEntry(x:188, y:178.83),
 ChartDataEntry(x:189, y:177.83),
 ChartDataEntry(x:190, y:179.92),
 ChartDataEntry(x:191, y:181.17),
 ChartDataEntry(x:192, y:177.26),
 ChartDataEntry(x:193, y:172.35),
 ChartDataEntry(x:194, y:172.53),
 ChartDataEntry(x:195, y:170.64),
 ChartDataEntry(x:196, y:173.70),
 ChartDataEntry(x:197, y:175.82),
 ChartDataEntry(x:198, y:173.99),
 ChartDataEntry(x:199, y:172.21),
 ChartDataEntry(x:200, y:170.65),
 ChartDataEntry(x:201, y:168.11),
 ChartDataEntry(x:202, y:165.74),
 ChartDataEntry(x:203, y:163.42),
 ChartDataEntry(x:204, y:160.82),
 ChartDataEntry(x:205, y:159.38),
 ChartDataEntry(x:206, y:161.60),
 ChartDataEntry(x:207, y:160.83),
 ChartDataEntry(x:208, y:168.02),
 ChartDataEntry(x:209, y:172.47),
 ChartDataEntry(x:210, y:174.31),
 ChartDataEntry(x:211, y:175.29),
 ChartDataEntry(x:212, y:173.69),
 ChartDataEntry(x:213, y:172.03),
 ChartDataEntry(x:214, y:172.26),
 ChartDataEntry(x:215, y:173.28),
 ChartDataEntry(x:216, y:176.17),
 ChartDataEntry(x:217, y:173.13),
 ChartDataEntry(x:218, y:170.49),
 ChartDataEntry(x:219, y:168.13),
 ChartDataEntry(x:220, y:171.88),
 ChartDataEntry(x:221, y:172.20),
 ChartDataEntry(x:222, y:169.96),
 ChartDataEntry(x:223, y:168.56),
 ChartDataEntry(x:224, y:164.65),
 ChartDataEntry(x:225, y:162.81),
 ChartDataEntry(x:226, y:157.66),
 ChartDataEntry(x:227, y:164.35),
 ChartDataEntry(x:228, y:164.09),
 ChartDataEntry(x:229, y:163.95),
 ChartDataEntry(x:230, y:165.47),
 ChartDataEntry(x:231, y:167.35),
 ChartDataEntry(x:232, y:163.83),
 ChartDataEntry(x:233, y:161.33),
 ChartDataEntry(x:234, y:158.13),
 ChartDataEntry(x:235, y:162.21),
 ChartDataEntry(x:236, y:159.36),
 ChartDataEntry(x:237, y:156.83),
 ChartDataEntry(x:238, y:151.03),
 ChartDataEntry(x:239, y:152.99),
 ChartDataEntry(x:240, y:158.32),
 ChartDataEntry(x:241, y:159.61),
 ChartDataEntry(x:242, y:162.24),
 ChartDataEntry(x:243, y:164.45),
 ChartDataEntry(x:244, y:167.17),
 ChartDataEntry(x:245, y:169.10),
 ChartDataEntry(x:246, y:172.57),
 ChartDataEntry(x:247, y:174.30),
 ChartDataEntry(x:248, y:173.89),
 ChartDataEntry(x:249, y:177.83),
 ChartDataEntry(x:250, y:178.16),
 ChartDataEntry(x:251, y:176.22),
 ChartDataEntry(x:252, y:174.17),
 ChartDataEntry(x:253, y:176.51),
 ChartDataEntry(x:254, y:176.28)
 */
