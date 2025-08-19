//
//  SearchStockViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

protocol SearchStocksViewCellDelegate: AnyObject {
    func didTapAddButton(in cell: SearchStocksViewCell, isAdded: Bool, ticker: String)
}

class SearchStocksViewCell: UITableViewCell {
    static let identifier = "SearchStocksViewCell"
    
    // Existing labels
    private let stockLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private let stockNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        return label
    }()
    
    private let exchangeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        return label
    }()
    
    // New button
    private let addButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 12 // Half of 12 for a circular shape
        button.clipsToBounds = true
        button.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 2)), for: .normal)
        return button
    }()
    
    // State to track if stock is added
    private var isAdded = false
    private var ticker: String = ""
    
    // Delegate to notify tap events
    weak var delegate: SearchStocksViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(stockLabel)
        contentView.addSubview(stockNameLabel)
        contentView.addSubview(exchangeLabel)
        contentView.addSubview(addButton)
        
        // Add target for button tap
        addButton.addAction(UIAction { [weak self] _ in
            self?.addButtonTapped()
        }, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Layout for labels
        let padding: CGFloat = 15
        let buttonSize: CGFloat = 24
        let labelWidth = contentView.frame.width - (2 * padding) - buttonSize - 8 // 8 for spacing between button and exchangeLabel
        
        // Calculate stockLabel width dynamically
            let stockLabelSize = stockLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: contentView.frame.height / 2.2))
            let stockLabelWidth = stockLabelSize.width
        
        stockLabel.frame = CGRect(
            x: padding,
            y: 5,
            width: stockLabelWidth,
            height: contentView.frame.height / 2.2
        )
        
        stockNameLabel.frame = CGRect(
            x: padding,
            y: stockLabel.frame.maxY + 2,
            width: labelWidth,
            height: contentView.frame.height / 2.6
        )
        
        exchangeLabel.frame = CGRect(
            x: stockLabel.frame.maxX + 8,
                y: 7,
                width: labelWidth,
                height: contentView.frame.height / 2.6
            )
        
        // Layout for button: bottom-right corner
        addButton.frame = CGRect(
            x: contentView.frame.width - padding - buttonSize,
            y: (contentView.frame.height / 2) - buttonSize / 2,
            width: buttonSize,
            height: buttonSize
        )
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let expandedButtonFrame = addButton.frame.insetBy(dx: -15, dy: -15)
        if expandedButtonFrame.contains(point) {
            return addButton
        }
        return super.hitTest(point, with: event)
    }
    
    
    public func configure(ticker: String, name: String, exchange: String, isAdded: Bool = false) {
        self.ticker = ticker
        self.isAdded = isAdded
        stockLabel.text = ticker
        stockNameLabel.text = name
        exchangeLabel.text = exchange
        updateButtonAppearance()
    }
    
    private func updateButtonAppearance() {
        let imageName = isAdded ? "checkmark" : "plus"
        addButton.setImage(UIImage(systemName: imageName), for: .normal)
        addButton.backgroundColor = isAdded ? .red : .blue
    }
    
    private func addButtonTapped() {
        isAdded.toggle()
        updateButtonAppearance()
        delegate?.didTapAddButton(in: self, isAdded: isAdded, ticker: ticker)
    }
}
