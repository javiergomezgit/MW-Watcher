//
//  SaveFeeds.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/11/21.
//



//import Foundation
import CoreData
import UIKit

class SaveFeeds {
    
    var feedsManagedObject: [NSManagedObject] = []
    let entityName = "RSS"
    
    func saveRSS(title: String, link: String, pubDate: String, ticker: String, linkTicker: String, image: UIImage ) {
    
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let feed = NSManagedObject(entity: entity, insertInto: managedContext)
      
        feed.setValue(title, forKeyPath: "title")
        feed.setValue(link, forKey: "link")
        feed.setValue(pubDate, forKey: "pubDate")
        feed.setValue(ticker, forKey: "ticker")
        feed.setValue(linkTicker, forKey: "linkTicker")
        
        guard let imageToData = image.jpegData(compressionQuality: 1) else {
            print("jpg error")
            return
            }
        feed.setValue(imageToData, forKey: "image")

        do {
            try managedContext.save()
            feedsManagedObject.append(feed)
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func deleteFeeds() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try managedContext.execute(deleteRequest)
            try managedContext.save()
        } catch {
            print ("there is an error")
        }
    }
    
    func loadFeeds() -> [RSSItemWithImages] {
        //guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        var feedItems : [RSSItemWithImages] = []
        
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let managedContext = appDelegate!.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            feedsManagedObject = try managedContext.fetch(fetchRequest)
            print (feedsManagedObject.count)

            for feed in feedsManagedObject {
                let title = feed.value(forKey: "title") as! String
                let link = feed.value(forKey: "link") as! String
                let pubDate = feed.value(forKey: "pubDate") as! String
                let ticker = feed.value(forKey: "ticker") as! String
                let linkTicker = feed.value(forKey: "linkTicker") as! String
                
                let imageData = feed.value(forKey: "image") as! Data
                var imageFromData = UIImage()
                do {
                    if let image = UIImage(data: imageData) {
                        imageFromData = image
                    } else {
                        imageFromData = UIImage(named: "mw-logo")!
                    }
                }
                
                let feedItem = RSSItemWithImages.init(title: title, link: link, pubDate: pubDate, ticker: ticker, linkTicker: linkTicker, rssImage: imageFromData)
                feedItems.append(feedItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return feedItems
            
    }
   
}
