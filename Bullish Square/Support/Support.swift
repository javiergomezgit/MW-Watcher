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
    
    
    //MARK: Download image from a url, caching the result
    let imageCache = NSCache<NSString, UIImage>()
    
    ///Asynchronous image download. Returns nil when the url is unusable, the request fails, or
    ///the payload is not a decodable image, so the caller decides on the fallback.
    ///Replaces a synchronous Data(contentsOf:) that blocked whichever queue called it — when
    ///several downloads were kicked off at once from a URLSession completion handler, they
    ///starved that handler's queue and images silently fell back to the placeholder.
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = imageCache.object(forKey: urlString as NSString) {
            completion(cached)
            return
        }
        
        guard urlString.isValidURL, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard error == nil, let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            self?.imageCache.setObject(image, forKey: urlString as NSString)
            completion(image)
        }.resume()
    }
    
    ///Downloads the given images concurrently and writes them into a copy of `items`.
    ///Entries with no url, or whose download fails, keep the image they already carry.
    func fillImages<T>(into items: [T],
                       urls: [Int: String],
                       imagePath: WritableKeyPath<T, UIImage>,
                       completion: @escaping ([T]) -> Void) {
        guard !urls.isEmpty else {
            completion(items)
            return
        }
        
        var result = items
        let group = DispatchGroup()
        let serial = DispatchQueue(label: "com.bullishsquare.imagefill")
        
        for (index, urlString) in urls where index < result.count {
            group.enter()
            downloadImage(from: urlString) { image in
                if let image = image {
                    serial.sync { result[index][keyPath: imagePath] = image }
                }
                group.leave()
            }
        }
        
        group.notify(queue: serial) {
            completion(result)
        }
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

//MARK: Placeholder avatar for tickers with no logo
extension UIImage {
    ///A tinted circle carrying the symbol's first letters, used when the provider has no logo
    ///for a ticker so the row reads as deliberate rather than broken.
    static func letterAvatar(for ticker: String, size: CGFloat = 120) -> UIImage {
        let symbol = ticker.replacingOccurrences(of: "^", with: "")
        let letters = String(symbol.prefix(2)).uppercased()
        
        //Seeded by hand: String.hashValue is randomised per process, so the colour would
        //change on every launch.
        let seed = symbol.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let background = UIColor(hue: CGFloat(seed % 360) / 360.0,
                                 saturation: 0.45,
                                 brightness: 0.75,
                                 alpha: 1.0)
        
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: bounds.size).image { context in
            background.setFill()
            context.cgContext.fillEllipse(in: bounds)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.38, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let text = letters as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: bounds.midX - textSize.width / 2,
                                  y: bounds.midY - textSize.height / 2),
                      withAttributes: attributes)
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
