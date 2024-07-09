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
        let time = timeString
        let date = Date(timeIntervalSince1970: Double(time)!)

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "PST")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = dateFormat
        let newFormatDate = dateFormatter.string(from: date)
        return newFormatDate
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


//MARK: Fixings for libraries
/* Replace this:
 internal static let EaseOutBack = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
 let s: TimeInterval = 1.70158
 var position: TimeInterval = elapsed / duration
 position -= 1.0
 return Double( position * position * ((s + 1.0) * position + s) + 1.0 )
 }
 
For this:
internal static let EaseOutBack = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
    let s: TimeInterval = 1.70158
    var position: TimeInterval = elapsed / duration
    position -= 1.0
    let position2 = (s + 1.0) * position + s
    return Double( position * position * (position2) + 1.0 )
}
*/
