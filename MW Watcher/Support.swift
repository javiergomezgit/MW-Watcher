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
    
    //Change date format for ALL live news
    func newLocalTimeNews(timeString: String) -> String {
        
        let date = timeString.components(separatedBy: ".")
        
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatterGet.timeZone = TimeZone(identifier: "CDT")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone(identifier: "PDT")//NSTimeZone(name: "America/Los_Angeles") as TimeZone?
        
        let dateObj: Date? = dateFormatterGet.date(from: date[0] + "Z")
        return dateFormatter.string(from: dateObj!)
    }
    
    //Change date format News specific stock
    func newLocalTime(timeString: String) -> String {
        print (timeString)
        //Get date and format
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        dateFormatterGet.timeZone = TimeZone(identifier: "UTC")
        
        //Convert format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current
        
        let dateObj: Date? = dateFormatterGet.date(from: timeString)
        let newLocalTime = dateFormatter.string(from: dateObj!)
        
        return newLocalTime
    }
    
    //Change date format for time stamp format
    func convertTimeStampToDate(timeString: String, dateFormat: String) -> String{
        let time = timeString
        let date = Date(timeIntervalSince1970: Double(time)!)

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "PST") //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = dateFormat //Specify your format that you want
        let newFormatDate = dateFormatter.string(from: date)
        return newFormatDate
    }
    
    
    //Download image with and save in cache
    let imageCache = NSCache<NSString, UIImage>()
    func downloadImageFeed(URLImage: String) -> UIImage {
        var image = UIImage()
        let url = URL(string: URLImage)
        do {
            let data = try Data(contentsOf: url!)
            let imageToCache = UIImage(data: data)!
            imageCache.setObject(imageToCache, forKey: URLImage as NSString)
            image = imageToCache
        } catch {
            image = UIImage(named: "mw-logo")!
        }
        return image
    }
    
}


//MARK: - Button delegate
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
