//
//  ComparisonChart.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/24/26.
//

import SwiftUI
import Charts
import UIKit

///Lines of percent change on one axis, against a dashed 0% line: the Markets tab's three
///indexes and the Simulated Portfolio's indexes plus the watchlist (BS-328). Swift Charts, like
///the stock chart; it replaced the last two DGCharts views, so the pod could go.
///
///The values are already percent changes, one per time slot, so the x axis is the slot number
///and is hidden; both screens say the time span elsewhere.
struct ComparisonSeries: Equatable {
    let name: String
    let color: UIColor
    ///Percent change per slot: 1.5 is +1.5%.
    let values: [Double]
    var lineWidth: CGFloat = 2
    ///Dots on each value, for the one line the screen is about (the portfolio).
    var showsPoints = false
}

final class ComparisonChartModel: ObservableObject {

    @Published var series: [ComparisonSeries] = []

    ///One value of one line, flattened so the chart builds from a single list.
    fileprivate struct Point: Identifiable {
        let id: String
        let series: String
        let slot: Int
        let value: Double
    }

    fileprivate var points: [Point] {
        series.flatMap { line in
            line.values.enumerated().compactMap { slot, value in
                //A gap or a division by zero upstream must not drag the axis to infinity.
                value.isFinite ? Point(id: "\(line.name)-\(slot)", series: line.name, slot: slot, value: value) : nil
            }
        }
    }

    ///Puts the chart inside `container`, filling it, as a child of `parent` so it follows the
    ///screen's dark mode and text size. Returns the model to set lines on.
    static func install(in container: UIView, parent: UIViewController) -> ComparisonChartModel {
        let model = ComparisonChartModel()
        let host = UIHostingController(rootView: ComparisonChartView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        parent.addChild(host)
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        host.didMove(toParent: parent)
        return model
    }
}

struct ComparisonChartView: View {

    @ObservedObject var model: ComparisonChartModel

    var body: some View {
        let points = model.points
        let dotted = Set(model.series.filter(\.showsPoints).map(\.name))
        let widths = Dictionary(model.series.map { ($0.name, $0.lineWidth) }, uniquingKeysWith: { first, _ in first })

        return Chart {
            RuleMark(y: .value("No change", 0))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            ForEach(points) { point in
                LineMark(x: .value("Time", point.slot),
                         y: .value("Change", point.value),
                         series: .value("Line", point.series))
                    .foregroundStyle(by: .value("Line", point.series))
                    .lineStyle(StrokeStyle(lineWidth: widths[point.series] ?? 2))
                    .interpolationMethod(.monotone)
            }

            ForEach(points.filter { dotted.contains($0.series) }) { point in
                PointMark(x: .value("Time", point.slot), y: .value("Change", point.value))
                    .foregroundStyle(by: .value("Line", point.series))
                    .symbolSize(18)
            }
        }
        .chartForegroundStyleScale(domain: model.series.map(\.name),
                                   range: model.series.map { Color(uiColor: $0.color) })
        .chartXAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(Self.percentText(percent))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
        .padding(.vertical, 4)
    }

    ///"+1.5%", "0%", "-0.8%".
    private static func percentText(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == 0 { return "0%" }
        let text = rounded == rounded.rounded() ? String(format: "%.0f%%", abs(rounded)) : String(format: "%.1f%%", abs(rounded))
        return (rounded > 0 ? "+" : "-") + text
    }
}
