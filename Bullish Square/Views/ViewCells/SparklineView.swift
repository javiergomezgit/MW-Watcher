//
//  SparklineView.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/29/26.
//

import UIKit

///A small intraday price line for a watchlist row: the session's closes, a fill fading out
///below them, and a dashed line at the previous close so an up or down day reads at a glance.
///
///Drawn with shape layers rather than a DGCharts view. A full chart in every row is heavy to
///build and lay out while scrolling; these layers are composited on the GPU and only rebuild
///their paths when the data or the size changes.
final class SparklineView: UIView {

    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAGradientLayer()
    private let fillMask = CAShapeLayer()
    private let baselineLayer = CAShapeLayer()

    private var closes: [Double] = []
    private var previousClose: Double = 0
    private var isUp = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        //Taps fall through to the row's open-chart button underneath.
        isUserInteractionEnabled = false
        backgroundColor = .clear

        baselineLayer.fillColor = nil
        baselineLayer.lineWidth = 1
        baselineLayer.lineDashPattern = [3, 3]

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 1.5
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round

        fillLayer.mask = fillMask

        layer.addSublayer(fillLayer)
        layer.addSublayer(baselineLayer)
        layer.addSublayer(lineLayer)
    }

    ///`isUp` comes from the caller rather than being worked out here, so the line's colour is
    ///always the same decision as the row's percentage and arrow. Recomputing it from the
    ///closes could disagree with a change that rounds to 0.00.
    func configure(closes: [Double], previousClose: Double, isUp: Bool) {
        self.closes = closes
        self.previousClose = previousClose
        self.isUp = isUp
        setNeedsLayout()
    }

    func reset() {
        configure(closes: [], previousClose: 0, isUp: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        //Layer colours are CGColors resolved once, so a light/dark switch needs a redraw.
        setNeedsLayout()
    }

    private func redraw() {
        //Paths and colours change instantly. Without this, a reused row animates from the
        //previous stock's line to the new one.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        fillLayer.frame = bounds
        fillMask.frame = bounds

        guard let geometry = Self.geometry(closes: closes, previousClose: previousClose, in: bounds.size),
              let first = geometry.points.first,
              let last = geometry.points.last else {
            lineLayer.path = nil
            fillMask.path = nil
            baselineLayer.path = nil
            return
        }

        let color = UIColor(named: isUp ? "uptrend" : "downtrend") ?? .label

        let line = UIBezierPath()
        line.move(to: first)
        geometry.points.dropFirst().forEach { line.addLine(to: $0) }
        lineLayer.path = line.cgPath
        lineLayer.strokeColor = color.cgColor

        let fill = UIBezierPath(cgPath: line.cgPath)
        fill.addLine(to: CGPoint(x: last.x, y: bounds.height))
        fill.addLine(to: CGPoint(x: first.x, y: bounds.height))
        fill.close()
        fillMask.path = fill.cgPath
        fillLayer.colors = [color.withAlphaComponent(0.35).cgColor, color.withAlphaComponent(0).cgColor]

        if let baselineY = geometry.baselineY {
            let baseline = UIBezierPath()
            baseline.move(to: CGPoint(x: 0, y: baselineY))
            baseline.addLine(to: CGPoint(x: bounds.width, y: baselineY))
            baselineLayer.path = baseline.cgPath
            baselineLayer.strokeColor = (UIColor(named: "colorSecondary") ?? .secondaryLabel).withAlphaComponent(0.6).cgColor
        } else {
            baselineLayer.path = nil
        }
    }

    // MARK: - Geometry

    struct Geometry {
        let points: [CGPoint]
        let baselineY: CGFloat?
    }

    ///Where each close lands in a view of `size`. Pure, so it can be checked on its own.
    ///
    ///Fewer than two closes gives nil: there is no line before the session's first trade, or
    ///for a ticker the API left out. The vertical range includes the previous close so the
    ///dashed baseline always sits inside the view, and a flat range is widened rather than
    ///divided by zero.
    static func geometry(closes: [Double], previousClose: Double, in size: CGSize, inset: CGFloat = 2) -> Geometry? {
        guard closes.count >= 2, size.width > 0, size.height > inset * 2 else { return nil }

        let hasBaseline = previousClose > 0
        let values = hasBaseline ? closes + [previousClose] : closes
        guard var low = values.min(), var high = values.max() else { return nil }
        if high - low < .ulpOfOne {
            low -= 1
            high += 1
        }

        let usableHeight = size.height - inset * 2
        func y(_ value: Double) -> CGFloat {
            inset + CGFloat((high - value) / (high - low)) * usableHeight
        }

        let step = size.width / CGFloat(closes.count - 1)
        let points = closes.enumerated().map { index, close in
            CGPoint(x: CGFloat(index) * step, y: y(close))
        }

        return Geometry(points: points, baselineY: hasBaseline ? y(previousClose) : nil)
    }
}
