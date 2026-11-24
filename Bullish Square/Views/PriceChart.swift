//
//  PriceChart.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import Charts
import SwiftUI
import UIKit

// MARK: - Data

///One bar of a price chart, from a stock, index or coin. Prices are already numbers; the
///chart never parses text.
struct PricePoint: Equatable {
    ///Unix seconds at the start of the bar.
    let time: TimeInterval
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    var date: Date { Date(timeIntervalSince1970: time) }
}

// MARK: - Model

///What the chart draws and what the finger is on. ChartController owns one and changes it;
///the SwiftUI view redraws on its own.
///
///Bars are placed by position, not by time, the way Apple's Stocks does it: by time, a week of
///hourly bars would be mostly empty nights and a weekend.
final class PriceChartModel: ObservableObject {

    @Published var points: [PricePoint] = [] {
        didSet { selection = nil }
    }
    @Published var showsCandles = false {
        didSet { selection = nil }
    }
    ///A dashed line across the chart, such as the previous close on a 1D chart. Also decides
    ///the colour: a day is up or down against the previous close, not against its first bar.
    @Published var baseline: Double?
    ///DateFormatter pattern for the few labels under the chart, such as "h a" or "MMM".
    @Published var axisFormat = "h a"
    ///Stocks are read in New York time, the market's own; coins in the phone's.
    @Published var timeZone = TimeZone.current

    ///Set by the chart while a finger is on it (iOS 17's chart selection), nil when it lifts.
    @Published var selection: Double? {
        didSet {
            let index = selectedIndex
            guard index != reportedIndex else { return }
            reportedIndex = index
            let drawn = drawnPoints
            onScrub?(index.map { drawn[$0] })
        }
    }

    ///Called with the bar under the finger, and with nil when it lifts. Once per bar, not per
    ///point of movement, so the header and haptics update only when the bar changes.
    var onScrub: ((PricePoint?) -> Void)?
    private var reportedIndex: Int?

    var selectedIndex: Int? {
        let drawn = drawnPoints
        guard let selection, !drawn.isEmpty else { return nil }
        return min(max(Int(selection.rounded()), 0), drawn.count - 1)
    }

    ///Most candles a chart draws. Past this a candle is a pixel wide and its body can't be seen.
    static let maxCandles = 70

    ///What is on screen: every bar for the line; for candles, neighbouring bars merged until at
    ///most `maxCandles` remain, so 1Y reads as about weekly candles and 5Y as about monthly.
    var drawnPoints: [PricePoint] {
        showsCandles ? Self.merged(points, maxBars: Self.maxCandles) : points
    }

    ///Consecutive bars as one candle: the first one's open and time, the last one's close, the
    ///highest high and the lowest low. Grouped from the newest end, so the latest candle is
    ///always whole and the partial group, if any, is the oldest.
    static func merged(_ points: [PricePoint], maxBars: Int) -> [PricePoint] {
        guard points.count > maxBars, maxBars > 0 else { return points }
        let size = Int((Double(points.count) / Double(maxBars)).rounded(.up))
        var groups: [PricePoint] = []
        var end = points.count
        while end > 0 {
            let group = points[max(end - size, 0)..<end]
            guard let first = group.first, let last = group.last else { break }
            groups.append(PricePoint(time: first.time, open: first.open,
                                     high: group.map(\.high).max() ?? last.high,
                                     low: group.map(\.low).min() ?? last.low,
                                     close: last.close))
            end -= size
        }
        return groups.reversed()
    }

    var isUp: Bool {
        guard let last = points.last?.close else { return true }
        let reference = baseline ?? points.first?.close ?? last
        return last >= reference
    }

    // MARK: Sharing

    ///The chart as an image for Share and Community posts. Drawn by SwiftUI itself: capturing
    ///the on-screen layer does not include SwiftUI content.
    @MainActor
    func snapshot(size: CGSize, style: UIUserInterfaceStyle) -> UIImage? {
        let content = PriceChartView(model: self, interactive: false)
            .padding(8)
            .frame(width: size.width, height: size.height)
            .background(Color(uiColor: .systemBackground))
            .environment(\.colorScheme, style == .dark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - View

struct PriceChartView: View {
    @ObservedObject var model: PriceChartModel
    ///Off for the share image, so it never shows a selection line.
    var interactive = true

    private static let up = Color(uiColor: UIColor(named: "uptrend") ?? .systemGreen)
    private static let down = Color(uiColor: UIColor(named: "downtrend") ?? .systemRed)

    var body: some View {
        //The chart's width decides how wide a candle's body can be.
        GeometryReader { geometry in
            chart(width: geometry.size.width)
        }
    }

    ///A candle body's width in points: 60% of each bar's slot, kept between 1 and 14 so a 5Y
    ///chart's 260 bars stay visible and a 1D chart's 20 aren't slabs. `.ratio` can't be used:
    ///it only sizes bars on a category axis, and on this numeric axis it drew no body at all.
    private func candleWidth(chartWidth: CGFloat, count: Int) -> CGFloat {
        //About 50 points go to the price labels on the right.
        let plotWidth = max(chartWidth - 50, 1)
        return min(max(plotWidth / CGFloat(max(count, 1)) * 0.6, 1), 14)
    }

    private func chart(width: CGFloat) -> some View {
        let points = model.drawnPoints
        let bodyWidth = candleWidth(chartWidth: width, count: points.count)
        let color = model.isUp ? Self.up : Self.down
        let domain = yDomain(points)

        return Chart {
            if model.showsCandles {
                ForEach(points.indices, id: \.self) { index in
                    let point = points[index]
                    let barColor = point.close >= point.open ? Self.up : Self.down
                    RuleMark(x: .value("Time", Double(index)),
                             yStart: .value("Low", point.low),
                             yEnd: .value("High", point.high))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(barColor)
                    //A bar that opened and closed at the same price still shows as a line.
                    RectangleMark(x: .value("Time", Double(index)),
                                  yStart: .value("Open", point.open),
                                  yEnd: .value("Close", point.open == point.close ? point.close + (domain.upperBound - domain.lowerBound) * 0.002 : point.close),
                                  width: .fixed(bodyWidth))
                        .foregroundStyle(barColor)
                }
            } else {
                ForEach(points.indices, id: \.self) { index in
                    AreaMark(x: .value("Time", Double(index)),
                             yStart: .value("Floor", domain.lowerBound),
                             yEnd: .value("Price", points[index].close))
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", Double(index)), y: .value("Price", points[index].close))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                        //Smoothed, but monotone: the curve never bulges above a real high or
                        //below a real low, which a plain spline would.
                        .interpolationMethod(.monotone)
                }
            }

            if let baseline = model.baseline {
                RuleMark(y: .value("Previous close", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundStyle(Color.secondary)
            }

            if interactive, let index = model.selectedIndex {
                RuleMark(x: .value("Selected", Double(index)))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.primary.opacity(0.5))
                if !model.showsCandles {
                    PointMark(x: .value("Selected", Double(index)), y: .value("Price", points[index].close))
                        .symbolSize(60)
                        .foregroundStyle(color)
                }
            }
        }
        //Half a bar of room each side, so the first and last candles aren't cut in half.
        .chartXScale(domain: -0.5...(Double(max(points.count - 1, 0)) + 0.5))
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: xTicks(points.count)) { value in
                AxisValueLabel {
                    if let position = value.as(Double.self), points.indices.contains(Int(position)) {
                        Text(axisLabel(points[Int(position)].date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel()
            }
        }
        .chartXSelection(value: interactive ? $model.selection : .constant(nil))
        .accessibilityLabel("Price chart")
        .accessibilityValue(accessibilitySummary(points))
    }

    ///From the lowest to the highest price shown, with a little room, never from zero: a stock
    ///moving 2% would otherwise be a flat line at the top.
    private func yDomain(_ points: [PricePoint]) -> ClosedRange<Double> {
        let lows = points.map { model.showsCandles ? $0.low : $0.close }
        let highs = points.map { model.showsCandles ? $0.high : $0.close }
        var low = lows.min() ?? 0
        var high = highs.max() ?? 1
        if let baseline = model.baseline {
            low = min(low, baseline)
            high = max(high, baseline)
        }
        let pad = high > low ? (high - low) * 0.06 : max(abs(high) * 0.01, 0.01)
        return (low - pad)...(high + pad)
    }

    ///Four labels, kept in from the edges so the first and last aren't clipped.
    private func xTicks(_ count: Int) -> [Double] {
        guard count > 3 else { return (0..<count).map(Double.init) }
        return [0.08, 0.36, 0.64, 0.92].map { (Double(count - 1) * $0).rounded() }
    }

    private func axisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = model.timeZone
        formatter.dateFormat = model.axisFormat
        return formatter.string(from: date)
    }

    private func accessibilitySummary(_ points: [PricePoint]) -> String {
        guard let first = points.first, let last = points.last else { return "No data" }
        let change = first.close > 0 ? (last.close - first.close) / first.close * 100 : 0
        return String(format: "From %.2f to %.2f, %@%.1f%%", first.close, last.close, change >= 0 ? "up " : "down ", abs(change))
    }
}
