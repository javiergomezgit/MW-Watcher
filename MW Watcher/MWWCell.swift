//
//  MWWCell.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit

class MWWCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pubdateLabel: UILabel!
    @IBOutlet weak var tickerLabel: UILabel!
    @IBOutlet weak var linkButton: UIButton!
    @IBOutlet var imageViewFeed: UIImageView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
        
    static let identifier = "MWWCustomCell"
    
    static func nib() -> UINib {
        return UINib(nibName: "MWWCell", bundle: nil)
    }
    
    public func setRSSValues(title: String, description: String, link: String, pubdate: String, ticker: String, imageFeed: UIImage) {
        
        titleLabel.text = title
        linkButton.titleLabel?.text = link
        pubdateLabel.text = pubdate
        imageViewFeed.image = imageFeed
        tickerLabel.text = ticker

        //isTickerPositive(tickerValue: description)
    }
  
    
    func loadLinkQuery(linkString: String) -> String {
        let limitString = linkString.maxLength(length: 50)
        let cleanString = limitString.convertedToSlug()!
        print (cleanString)
        let newString = "http://www.google.com/search?q=\(cleanString)"
        print (newString)
        return newString
    }
    
    
    func isTickerPositive(tickerValue: String){
        tickerLabel.text = tickerValue
        if !tickerValue.isEmpty {
            if tickerValue.contains("-") {
                tickerLabel.textColor = UIColor(red: 231/255, green: 81/255, blue: 62/255, alpha: 1.0)
                //backgroundCell.backgroundColor = UIColor.red.withAlphaComponent(0.05)
            } else {
                tickerLabel.textColor = UIColor(red: 32/255, green: 197/255, blue: 176/255, alpha: 1.0)
                //backgroundCell.backgroundColor = UIColor.blue.withAlphaComponent(0.05)

            }
        }
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}



extension String {
    private static let slugSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-")

    public func convertedToSlug() -> String? {
        if let latin = self.applyingTransform(StringTransform("Any-Latin; Latin-ASCII; Lower;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: String.slugSafeCharacters.inverted)
            let result = urlComponents.filter { $0 != "" }.joined(separator: "%20")

            if result.count > 0 {
                return result
            }
        }

        return nil
    }
}

extension String {
   func maxLength(length: Int) -> String {
       var str = self
       let nsString = str as NSString
       if nsString.length >= length {
           str = nsString.substring(with:
               NSRange(
                location: 0,
                length: nsString.length > length ? length : nsString.length)
           )
       }
       return  str
   }
}

