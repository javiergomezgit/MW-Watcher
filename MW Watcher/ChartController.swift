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
    
    lazy var candleView: CandleStickChartView = {
        let candleView = CandleStickChartView()
        candleView.backgroundColor = .systemBlue
        
        return candleView
    }()
    
    lazy var lineChartView: LineChartView = {
        let chartView = LineChartView()
        chartView.backgroundColor = .systemBlue
        
        chartView.rightAxis.enabled = false
        
        let yAxis = chartView.leftAxis
        yAxis.labelFont = .boldSystemFont(ofSize: 12)
        yAxis.setLabelCount(4, force: false)
        yAxis.labelTextColor = .white
        yAxis.axisLineColor = .white
        yAxis.labelPosition = .outsideChart
        
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelFont = .boldSystemFont(ofSize: 12)
        chartView.xAxis.setLabelCount(3, force: false)
        chartView.xAxis.labelTextColor = .systemYellow
        chartView.xAxis.axisLineColor = .systemTeal
        
        chartView.animate(xAxisDuration: 2.5)
        
        
        return chartView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        view.addSubview(lineChartView)
//        lineChartView.centerInSuperview()
//        lineChartView.width(to: view)
//        lineChartView.heightToWidth(of: view)
        view.addSubview(candleView)
        candleView.centerInSuperview()
        candleView.width(to: view)
        candleView.heightToWidth(of: view)
    
        setData1()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        print(entry)
    }
    
    func setData() {
        let set1 = LineChartDataSet(entries: yValues, label: "Subscribs")
        
        set1.mode = .cubicBezier
        set1.drawCirclesEnabled = false
        set1.lineWidth = 3
        set1.setColor(.yellow)
        set1.fill = Fill(color: .white)
        set1.fillAlpha = 0.7
        set1.drawFilledEnabled = true
        
        set1.drawHorizontalHighlightIndicatorEnabled = false
        set1.highlightColor = .systemRed
        
        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        lineChartView.data = data
    }
    
    func setData1() {
        let set1 = CandleChartDataSet(entries: yV, label: "something")
                
        set1.axisDependency = .left
        set1.setColor(UIColor(white: 80/255, alpha: 1))
        set1.drawIconsEnabled = false
        set1.shadowColor = .white
        set1.shadowWidth = 0.9
        set1.decreasingColor = .red
        set1.decreasingFilled = true
        set1.increasingColor = .yellow
        set1.increasingFilled = true
        set1.neutralColor = .orange
        
        let data = CandleChartData(dataSet: set1)
        candleView.data = data
    }
    
    
    let yV: [CandleChartDataEntry] = [
        CandleChartDataEntry(x: 1, shadowH: 9, shadowL: 2, open: 3.0, close: 6.5),
        CandleChartDataEntry(x: 2, shadowH: 7.1, shadowL: 13, open: 6.5, close: 14.0),
        CandleChartDataEntry(x: 3, shadowH: 17.1, shadowL: 11.7, open: 14.0, close: 16.5),
        CandleChartDataEntry(x: 4, shadowH: 17.1, shadowL: 11.7, open: 14.0, close: 16.5),
        CandleChartDataEntry(x: 5, shadowH: 7.0, shadowL: 9.8, open: 16.5, close: 9.8),
        CandleChartDataEntry(x: 6, shadowH: 2.0, shadowL: 9, open: 9.8, close: 6.5),
        CandleChartDataEntry(x: 7, shadowH: 7.1, shadowL: 13, open: 6.5, close: 14.0),
        CandleChartDataEntry(x: 8, shadowH: 14.0, shadowL: 17.1, open: 14.0, close: 16.5),
        CandleChartDataEntry(x: 9, shadowH: 7.1, shadowL: 13, open: 16.5, close: 14.0),
        CandleChartDataEntry(x: 10, shadowH: 17.1, shadowL: 11.7, open: 14.0, close: 17.5),
        CandleChartDataEntry(x: 11, shadowH: 17.1, shadowL: 11.7, open: 17.5, close: 16.5),
        CandleChartDataEntry(x: 12, shadowH: 7.0, shadowL: 9.8, open: 16.5, close: 9.8),
        CandleChartDataEntry(x: 13, shadowH: 17.1, shadowL: 11.7, open: 9.8, close: 16.5),
        CandleChartDataEntry(x: 14, shadowH: 17.1, shadowL: 11.7, open: 16.5, close: 16.7),
        CandleChartDataEntry(x: 15, shadowH: 7.0, shadowL: 9.8, open: 16.7, close: 9.8),
        CandleChartDataEntry(x: 16, shadowH: 7.0, shadowL: 9.8, open: 9.8, close: 5.8),
        CandleChartDataEntry(x: 17, shadowH: 17.1, shadowL: 11.7, open: 5.8, close: 16.5),
        CandleChartDataEntry(x: 18, shadowH: 17.1, shadowL: 11.7, open: 16.5, close: 13.5),
        CandleChartDataEntry(x: 19, shadowH: 7.0, shadowL: 9.8, open: 13.5, close: 6.5),
        CandleChartDataEntry(x: 20, shadowH: 7.1, shadowL: 14, open: 6.5, close: 14.0),
        CandleChartDataEntry(x: 21, shadowH: 7.1, shadowL: 23.5, open: 14, close: 23),
        CandleChartDataEntry(x: 22, shadowH: 7.1, shadowL: 13, open: 23, close: 11.2),
        CandleChartDataEntry(x: 23, shadowH: 7.1, shadowL: 15, open: 11.2, close: 7),
        CandleChartDataEntry(x: 24, shadowH: 7.1, shadowL: 7, open: 7, close: 2.5),
        CandleChartDataEntry(x: 25, shadowH: 7.1, shadowL: 4, open: 2.5, close: 1.3),
        CandleChartDataEntry(x: 26, shadowH: 7.1, shadowL: 5, open: 1.3, close: 1.2),
        CandleChartDataEntry(x: 27, shadowH: 7.1, shadowL: 1.3, open: 1.2, close: 1.0),
        CandleChartDataEntry(x: 28, shadowH: 7.1, shadowL: 4.5, open: 1.0, close: 4.3),
        CandleChartDataEntry(x: 29, shadowH: 7.1, shadowL: 6, open: 4.3, close: 5.1),
        CandleChartDataEntry(x: 30, shadowH: 7.1, shadowL: 7.5, open: 5.1, close: 7.3),
        ]
    
    let yValues: [ChartDataEntry] = [
        ChartDataEntry(x: 0.0, y: 2.0),
        ChartDataEntry(x: 1.0, y: 5.0),
        ChartDataEntry(x: 2.0, y: 7.0),
        ChartDataEntry(x: 3.0, y: 5.0),
        ChartDataEntry(x: 4.0, y: 10.0),
        ChartDataEntry(x: 5.0, y: 6.0),
        ChartDataEntry(x: 6.0, y: 5.0),
        ChartDataEntry(x: 7.0, y: 7.0),
        ChartDataEntry(x: 8.0, y: 8.0),
        ChartDataEntry(x: 9.0, y: 12.0),
        ChartDataEntry(x: 10.0, y: 13.0),
        ChartDataEntry(x: 11.0, y: 10.0),
        ChartDataEntry(x: 12.0, y: 6.0),
        ChartDataEntry(x: 13.0, y: 5.0),
        ChartDataEntry(x: 14.0, y: 7.0),
        ChartDataEntry(x: 15.0, y: 5.0),
        ChartDataEntry(x: 16.0, y: 7.0),
        ChartDataEntry(x: 17.0, y: 8.0),
        ChartDataEntry(x: 18.0, y: 15.0),
        ChartDataEntry(x: 19.0, y: 1.0),
        ChartDataEntry(x: 20.0, y: 10.0),
        ChartDataEntry(x: 21.0, y: 6.0),
        ChartDataEntry(x: 22.0, y: 1.0),
        ChartDataEntry(x: 23.0, y: 6.0),
        ChartDataEntry(x: 24.0, y: 3.0),
        ChartDataEntry(x: 25.0, y: 6.0),
        ChartDataEntry(x: 26.0, y: 1.0),
        ChartDataEntry(x: 27.0, y: 6.0),
        ChartDataEntry(x: 28.0, y: 11.0),
        ChartDataEntry(x: 29.0, y: 9.0),
    ]
}
