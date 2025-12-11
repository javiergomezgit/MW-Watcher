//
//  Support.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/14/22.
//

import Foundation
import UIKit

class Support {
    static let sharedSupport = Support()
    
    //MARK: Change date format from UNIX to local
    func dateFormatUnixToLocal(timeInt: Int) -> String {
        // Validate timestamp
        guard timeInt > 0 else {
            return "Invalid timestamp"
        }
        
        // Format the date to local time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current
            
        // Create a Date object from the Unix timestamp
        let dateObj = Date(timeIntervalSince1970: Double(timeInt))
        
        let newLocalTime = dateFormatter.string(from: dateObj)
        print(newLocalTime) // Example output: Aug 20, 2025 at 1:12:26 PM (in PDT)
        return newLocalTime
    }
    
    //MARK: Change date format for All live news
    func newLocalTimeNews(timeString: String) -> String {
        
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatterGet.timeZone = TimeZone(abbreviation: "UTC")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone(identifier: "PDT")

        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        let newLocalTime = dateFormatter.string(from: dateObj!)
        return newLocalTime
    }
    
    //MARK: Change date format News specific stock
    func newLocalTime(timeString: String) -> String {
        //Get date and format
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")

        //Convert format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current

        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        if dateObj != nil {
            let newLocalTime = dateFormatter.string(from: dateObj!)
            return newLocalTime
        } else {
            return ""
        }
    }
    
    //MARK: Change date format News specific crypto
    func newLocalTimeCrypto(timeString: String) -> String {
        //Get date and format
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")

        //Convert format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current

        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        if dateObj != nil {
            let newLocalTime = dateFormatter.string(from: dateObj!)
            return newLocalTime
        } else {
            return ""
        }
    }
    
    
    //MARK: Change date format for time stamp format in chart stock/crypto screen
    func convertTimeStampToDate(timeString: String, dateFormat: String) -> String{
        let time = Double(timeString)
        if time != nil {
            let date = Date(timeIntervalSince1970: time!)
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(abbreviation: "PST")
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = dateFormat
            let newFormatDate = dateFormatter.string(from: date)
            return newFormatDate
        } else {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(abbreviation: "PST")
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = dateFormat
            let newFormatDate = dateFormatter.string(from: date)
            return newFormatDate
        }
    }
    
    
    //MARK: Download image from an url and save it in cache, if result in error return official logo
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage(named: "mw-logo")!
        if URLImage.isValidURL {
            let url = URL(string: URLImage)
            do {
                let data = try Data(contentsOf: url!)
                let imageToCache = UIImage(data: data)!
                imageCache.setObject(imageToCache, forKey: URLImage as NSString)
                image = imageToCache
            } catch {
                image = UIImage(named: "mw-logo")!
            }
        }
        return image
    }
    
    //MARK: Round edges of an image
    
}


//MARK: - Button delegate (animation button)
extension UIButton {
    func animateButton(sender: UIButton, duration: Double) {
        UIButton.animate(withDuration: duration,
                         animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        },
                         completion: { finish in
            UIButton.animate(withDuration: duration, animations: {
                sender.transform = CGAffineTransform.identity
            })
        }
        )
    }
}



//MARK: Validate url
extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
}

//MARK: Round edges for images
extension UIImageView {
    /// Rounds the corners by a percentage of the imageView’s height.
    func roundAllCorners(by percentage: CGFloat) {
        let radius = bounds.height * (percentage / 100)
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    /// Round specific corners with a radius by percentage.
    /// Use     imageNews.roundCorners([.topLeft, .topRight], radius: 10)
    func roundCorners(_ corners: UIRectCorner, percent: CGFloat) {
        layoutIfNeeded()  // ensure we have final bounds
        
        let modifiedPercent = percent / 100

        let minSide = min(bounds.width, bounds.height)
        let radius = minSide * modifiedPercent

        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}


//MARK: Round edges for images
extension UIView {
    /// Rounds the corners by a percentage of the imageView’s height.
    func roundAllCornersUIView(by percentage: CGFloat) {
        let radius = bounds.height * (percentage / 100)
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    /// Round specific corners with a radius by percentage.
    /// Use     imageNews.roundCorners([.topLeft, .topRight], radius: 10)
    func roundCornersUIView(_ corners: UIRectCorner, percent: CGFloat) {
        layoutIfNeeded()  // ensure we have final bounds
        
        let modifiedPercent = percent / 100

        let minSide = min(bounds.width, bounds.height)
        let radius = minSide * modifiedPercent

        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}
