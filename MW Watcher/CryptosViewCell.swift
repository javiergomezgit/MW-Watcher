//
//  CryptosViewCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 6/12/21.
//

import UIKit

struct CryptosViewCellModel {
    let symbol: String
    let name: String
    let price: String
    let change: String
    let changeMonth: String
    let volume: String
    let cryptoImage: UIImage
}

class CryptosViewCell: UITableViewCell {
    static let identifier = "CryptosViewCell"
    
    private let cryptoImageImageView: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleToFill
        return image
    }()
    
    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 25, weight: .bold)
        return label
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .regular)
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        return label
    }()
    
    private let volume24hrLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .gray
        return label
    }()
    
    private let changePercentageDayLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    private let changePercentageMonthLabel: UILabel = {
        let label = UILabel()
        //label.textColor = .darkGray
        label.textAlignment = .right
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    public let openCryptoChartButton: UIButton = {
        let button = UIButton()
        return button
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        priceLabel.text = nil
        symbolLabel.text = nil
        changePercentageDayLabel.text = nil
        changePercentageMonthLabel.text = nil
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(cryptoImageImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(symbolLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(changePercentageDayLabel)
        contentView.addSubview(changePercentageMonthLabel)
        contentView.addSubview(volume24hrLabel)
        contentView.addSubview(openCryptoChartButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        nameLabel.sizeToFit()
        priceLabel.sizeToFit()
        symbolLabel.sizeToFit()
        changePercentageDayLabel.sizeToFit()
        changePercentageMonthLabel.sizeToFit()
        volume24hrLabel.sizeToFit()
        openCryptoChartButton.sizeToFit()
        
        let size: CGFloat = contentView.frame.size.height * 0.9
        cryptoImageImageView.frame = CGRect(x: 0, y: (contentView.frame.size.height - (size-25))/2, width: size-25, height: size-25)
        
        symbolLabel.frame = CGRect(x: size-5, y: 0, width: contentView.frame.size.width/2, height: contentView.frame.size.height/2)
        nameLabel.frame = CGRect(x: size-5, y: contentView.frame.size.height/4, width: contentView.frame.size.width/2, height: contentView.frame.size.height/2)
        volume24hrLabel.frame = CGRect(x: size-5, y: contentView.frame.size.height/2, width: contentView.frame.size.width/2, height: contentView.frame.size.height/2)
        
        priceLabel.frame = CGRect(x: contentView.frame.size.width/2, y: 0, width: (contentView.frame.size.width/2)-15, height: contentView.frame.size.height/2)
        changePercentageDayLabel.frame = CGRect(x: contentView.frame.size.width/2, y: contentView.frame.size.height/4, width: (contentView.frame.size.width/2)-15, height: contentView.frame.size.height/2)
        changePercentageMonthLabel.frame = CGRect(x: contentView.frame.size.width/2, y: contentView.frame.size.height/2, width: (contentView.frame.size.width/2)-15, height: contentView.frame.size.height/2)
        
        openCryptoChartButton.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.height)
        
    }
    
    func configure(with viewModel: CryptosViewCellModel) {
        nameLabel.text = viewModel.name
        symbolLabel.text = viewModel.symbol
        priceLabel.text = viewModel.price
        volume24hrLabel.text = "Vol.\(viewModel.volume) MM"
        if Float(viewModel.change)! < 0.000 {
            changePercentageDayLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            changePercentageDayLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        
        if Float(viewModel.changeMonth)! < 0.000 {
            changePercentageMonthLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
        } else {
            changePercentageMonthLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
        }
        changePercentageDayLabel.text = "\(viewModel.change)% Day"
        changePercentageMonthLabel.text = "\(viewModel.changeMonth)% Month"
        cryptoImageImageView.image = viewModel.cryptoImage
    }
    
}



