//
//  ChartLoadingView.swift
//  Bullish Square
//
//  Created by Javier Gomez on 10/06/26.
//

import UIKit

///What the chart area shows while its candles load: faint grid lines and a placeholder price
///line with a highlight sweeping across it, in place of a dimmed overlay with a spinner.
///
///Opaque on purpose. During a timeframe switch the previous timeframe's chart is still
///underneath, and showing it through the overlay read as the new data having arrived.
final class ChartLoadingView: UIView {

    private let gridLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()
    private let shimmerLayer = CAGradientLayer()
    private let shimmerMask = CAShapeLayer()

    private static let shimmerKey = "shimmer"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = UIColor(named: "colorPrimary") ?? .systemBackground
        isAccessibilityElement = true
        accessibilityLabel = "Loading chart"
        accessibilityTraits = .updatesFrequently

        gridLayer.fillColor = nil
        gridLayer.lineWidth = 1
        gridLayer.lineDashPattern = [4, 4]

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2.5
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round

        //The highlight is a gradient band, visible only where the placeholder line is.
        shimmerMask.fillColor = nil
        shimmerMask.lineWidth = 2.5
        shimmerMask.lineCap = .round
        shimmerMask.lineJoin = .round
        shimmerMask.strokeColor = UIColor.black.cgColor
        shimmerLayer.mask = shimmerMask
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0.35, 0.5, 0.65]

        layer.addSublayer(gridLayer)
        layer.addSublayer(lineLayer)
        layer.addSublayer(shimmerLayer)
        applyColors()
    }

    ///CGColors do not follow light and dark mode on their own.
    private func applyColors() {
        let secondary = UIColor(named: "colorSecondary") ?? .secondaryLabel
        let accent = UIColor(named: "colorAccent") ?? .systemBlue
        gridLayer.strokeColor = secondary.withAlphaComponent(0.18).resolvedColor(with: traitCollection).cgColor
        lineLayer.strokeColor = secondary.withAlphaComponent(0.3).resolvedColor(with: traitCollection).cgColor
        let glow = accent.resolvedColor(with: traitCollection)
        shimmerLayer.colors = [glow.withAlphaComponent(0).cgColor,
                               glow.withAlphaComponent(0.9).cgColor,
                               glow.withAlphaComponent(0).cgColor]
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = bounds.insetBy(dx: 16, dy: 24)
        guard inset.width > 0, inset.height > 0 else { return }

        let grid = UIBezierPath()
        for step in 0...3 {
            let y = inset.minY + inset.height * CGFloat(step) / 3
            grid.move(to: CGPoint(x: inset.minX, y: y))
            grid.addLine(to: CGPoint(x: inset.maxX, y: y))
        }
        gridLayer.path = grid.cgPath

        let line = Self.placeholderLine(in: inset).cgPath
        lineLayer.path = line
        shimmerMask.path = line

        //The layer stays put and only the band inside it moves: moving the layer would carry
        //its mask along, and the highlight would slide off the line.
        shimmerLayer.frame = bounds
        shimmerMask.frame = bounds
        restartShimmer()
    }

    ///A gently rising, wandering line: reads as "a price chart" without suggesting any
    ///direction for the real one.
    private static func placeholderLine(in rect: CGRect) -> UIBezierPath {
        let shape: [CGFloat] = [0.62, 0.48, 0.55, 0.38, 0.45, 0.30, 0.42, 0.33, 0.20, 0.28]
        let path = UIBezierPath()
        let step = rect.width / CGFloat(shape.count - 1)
        var previous = CGPoint(x: rect.minX, y: rect.minY + rect.height * shape[0])
        path.move(to: previous)
        for (index, value) in shape.enumerated().dropFirst() {
            let point = CGPoint(x: rect.minX + step * CGFloat(index), y: rect.minY + rect.height * value)
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: middle, controlPoint: previous)
            previous = point
        }
        path.addLine(to: previous)
        return path
    }

    // MARK: - Animation

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restartShimmer()
    }

    ///Restarted on layout and on reappearing: Core Animation drops a running animation when
    ///the app goes to the background or the view leaves the window.
    private func restartShimmer() {
        shimmerLayer.removeAnimation(forKey: Self.shimmerKey)
        guard window != nil, bounds.width > 0, !UIAccessibility.isReduceMotionEnabled else { return }

        //From fully off the left edge to fully off the right one.
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.3, -0.15, 0.0]
        sweep.toValue = [1.0, 1.15, 1.3]
        sweep.duration = 1.4
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweep.isRemovedOnCompletion = false
        shimmerLayer.add(sweep, forKey: Self.shimmerKey)
    }
}
