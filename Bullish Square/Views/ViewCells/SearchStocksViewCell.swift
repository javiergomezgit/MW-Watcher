//
//  SearchStockViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

// Contract that the parent controller must implement to receive button tap events.
// Decouples the cell from the controller — cell doesn't need to know who owns it.
protocol SearchStocksViewCellDelegate: AnyObject {
    func didTapAddButton(in cell: SearchStocksViewCell, isAdded: Bool, ticker: String)
}

class SearchStocksViewCell: UITableViewCell {
    static let identifier = "SearchStocksViewCell"
    
    // MARK: - UI Elements
    
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
    
    private let addButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 12 // Half height — makes button circular
        button.clipsToBounds = true
        button.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 2)), for: .normal)
        return button
    }()
    
    // MARK: - State
    
    private var isAdded = false  // Tracks whether this stock is in the watchlist
    private var ticker: String = "" // Current stock ticker — set via configure()
    
    // Weak to avoid retain cycle — cell does not own the controller
    weak var delegate: SearchStocksViewCellDelegate?
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(stockLabel)
        contentView.addSubview(stockNameLabel)
        contentView.addSubview(exchangeLabel)
        contentView.addSubview(addButton)
        
        // UIAction with [weak self] prevents retain cycle between button and cell
        addButton.addAction(UIAction { [weak self] _ in
            self?.addButtonTapped()
        }, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let padding: CGFloat = 15
        let buttonSize: CGFloat = 24
        let labelWidth = contentView.frame.width - (2 * padding) - buttonSize - 8 // 8pt gap between label and button
        
        // Dynamic width based on text content — avoids clipping long tickers
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
            y: stockLabel.frame.maxY + 2, // 2pt gap below ticker label
            width: labelWidth,
            height: contentView.frame.height / 2.6
        )
        
        exchangeLabel.frame = CGRect(
            x: stockLabel.frame.maxX + 8, // Sits inline with ticker, 8pt to the right
            y: 7,
            width: labelWidth,
            height: contentView.frame.height / 2.6
        )
        
        addButton.frame = CGRect(
            x: contentView.frame.width - padding - buttonSize, // Pinned to right edge
            y: (contentView.frame.height / 2) - buttonSize / 2, // Vertically centered
            width: buttonSize,
            height: buttonSize
        )
    }
    
    // MARK: - Hit Testing
    
    // Expands the tappable area of the button by 15pt on each side —
    // makes small buttons easier to tap without changing their visual size
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let expandedButtonFrame = addButton.frame.insetBy(dx: -15, dy: -15)
        if expandedButtonFrame.contains(point) {
            return addButton
        }
        return super.hitTest(point, with: event)
    }
    
    // MARK: - Reuse
    
    // Resets all state before the cell is reused for a different row.
    // delegate is cleared first to prevent stale tap events firing on wrong data.
    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil // Cut delegate before clearing state — prevents stale tap delivery
        ticker = ""
        isAdded = false
        stockLabel.text = nil
        stockNameLabel.text = nil
        exchangeLabel.text = nil
        updateButtonAppearance()
    }
    
    // MARK: - Configuration
    
    // Called by cellForRowAt to populate the cell with stock data.
    // isAdded drives button appearance — checkmark if in watchlist, plus if not.
    public func configure(ticker: String, name: String, exchange: String, isAdded: Bool = false) {
        self.ticker = ticker
        self.isAdded = isAdded
        stockLabel.text = ticker
        stockNameLabel.text = name
        exchangeLabel.text = exchange
        updateButtonAppearance()
    }
    
    // MARK: - Private
    
    // Syncs button icon and color to current isAdded state
    private func updateButtonAppearance() {
        let imageName = isAdded ? "checkmark" : "plus"
        addButton.setImage(UIImage(systemName: imageName), for: .normal)
        addButton.backgroundColor = isAdded ? .red : .blue
    }
    
    // Notifies delegate on tap — controller owns save/delete logic and visual reload.
    // Cell does not toggle isAdded itself; controller calls configure() after handling the action.
    private func addButtonTapped() {
        delegate?.didTapAddButton(in: self, isAdded: isAdded, ticker: ticker)
    }
}
