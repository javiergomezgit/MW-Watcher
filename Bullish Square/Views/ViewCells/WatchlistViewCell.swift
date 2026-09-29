//
//  MyTickersViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import UIKit

class WatchlistViewCell: UITableViewCell {

    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var nameCompanyLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet var currentPriceLabel: UILabel!
    @IBOutlet var previousPriceLabel: UILabel!
    @IBOutlet var arrowImageView: UIImageView!
    @IBOutlet weak var openChartButton: UIButton!
    @IBOutlet weak var imageCompanyImageView: UIImageView!
    @IBOutlet weak var frameCoverLabel: UILabel!
    
    ///Built in code, so the storyboard prototype needs no change.
    let sparklineView = SparklineView()
    
    ///Below this row width the company name would be squeezed to a few characters, so the
    ///row goes without a sparkline. iOS 15 still runs on the 320pt first-generation iPhone SE.
    static let minimumWidthForSparkline: CGFloat = 350
    
    private var namesEndBeforeSparkline: [NSLayoutConstraint] = []
    private var namesEndBeforePrices: [NSLayoutConstraint] = []
    private var showsSparkline: Bool?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        installSparkline()
    }
    
    private func installSparkline() {
        sparklineView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sparklineView)
        
        //The arrow is the leftmost thing in the price column on both lines, so ending there
        //clears the price, the previous close and the change.
        NSLayoutConstraint.activate([
            sparklineView.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            sparklineView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            sparklineView.widthAnchor.constraint(equalToConstant: 70),
            sparklineView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        //The storyboard sizes the ticker and name labels as a fraction of the row's width,
        //with nothing holding their trailing edge. That width is released so each label ends
        //where the free space does, truncating a long name rather than running under the line.
        let labels: [UIView] = [tickerLabel, nameCompanyLabel]
        let widths = (contentView.constraints + tickerLabel.constraints + nameCompanyLabel.constraints).filter { constraint in
            labels.contains { label in
                (constraint.firstItem === label && constraint.firstAttribute == .width) ||
                (constraint.secondItem === label && constraint.secondAttribute == .width)
            }
        }
        if widths.count != labels.count {
            print("WatchlistViewCell expected \(labels.count) label width constraints, found \(widths.count)")
        }
        NSLayoutConstraint.deactivate(widths)
        
        namesEndBeforeSparkline = labels.map {
            $0.trailingAnchor.constraint(lessThanOrEqualTo: sparklineView.leadingAnchor, constant: -8)
        }
        namesEndBeforePrices = labels.map {
            $0.trailingAnchor.constraint(lessThanOrEqualTo: arrowImageView.leadingAnchor, constant: -8)
        }
    }
    
    override func layoutSubviews() {
        //Decided from the row's real width, which only exists at layout time; awakeFromNib
        //still sees the storyboard's. Only a change of answer touches the constraints.
        let shows = bounds.width >= Self.minimumWidthForSparkline
        if shows != showsSparkline {
            showsSparkline = shows
            sparklineView.isHidden = !shows
            NSLayoutConstraint.deactivate(shows ? namesEndBeforePrices : namesEndBeforeSparkline)
            NSLayoutConstraint.activate(shows ? namesEndBeforeSparkline : namesEndBeforePrices)
        }
        super.layoutSubviews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        sparklineView.reset()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        openChartButton.setTitle("", for: .normal)

    }

}
