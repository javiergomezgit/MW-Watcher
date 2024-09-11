//
//  SearchNewsViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 8/8/22.
//

import UIKit

class SearchNewsViewCell: UITableViewCell {

    static let identifier = "SearchNewsViewCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(newsLabel)
        contentView.addSubview(newsNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init has not been implemented")
    }
    
    private let newsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()
    private let newsNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        return label
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        newsLabel.frame = CGRect(x: 15, y: 5, width: contentView.frame.width - 30, height: (contentView.frame.height / 2.2))
        newsNameLabel.frame = CGRect(x: 15, y: newsLabel.frame.maxY + 1, width: contentView.frame.width - 30, height: (contentView.frame.height / 2.6))
    }
    
    public func configure(ticker: String, name: String) {
        newsLabel.text = ticker
        newsNameLabel.text = name
    }

}
