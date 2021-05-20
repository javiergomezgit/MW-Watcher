//
//  SaveFeedsWidget.swift
//  WidgetExtension
//
//  Created by Javier Gomez on 5/13/21.
//

import SwiftUI
import WidgetKit
import CoreData

public enum AppGroup: String {
    case facts = "group.mw-watcher"

    public var containerURL: URL {
        switch self {
        case .facts:
          return FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: self.rawValue)!
        }
    }
}

var feedsManagedObject: [NSManagedObject] = []

struct SaveFeedsWidget {

    func loadSavedFeeds() -> [RSSItem] {


        let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, Error in
            print (Error as Any)
        }
        let managedContext = container.viewContext
        
        var feedItems : [RSSItem] = []
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RSS")

        do {
            feedsManagedObject = try managedContext.fetch(fetchRequest)
            print (feedsManagedObject.count)

            for feed in feedsManagedObject {
                let title = feed.value(forKey: "title") as! String
                let link = feed.value(forKey: "link") as! String
                let pubDate = feed.value(forKey: "pubDate") as! String
                let ticker = feed.value(forKey: "ticker") as! String
                let linkTicker = feed.value(forKey: "linkTicker") as! String
                let enclosure = feed.value(forKey: "enclosure") as! String
                
                let feedItem = RSSItem.init(title: title, link: link, pubDate: pubDate, ticker: ticker, linkTicker: linkTicker, enclosure: enclosure)
                
                feedItems.append(feedItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return feedItems
    }

    
    func deleteSavedFeeds() {
        let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, Error in
            print (Error as Any)
        }
        let managedContext = container.viewContext
        
        
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RSS")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedContext.execute(deleteRequest)
            try managedContext.save()
        } catch {
            print (error)
        }
        
    }
    func saveOnlineFeeds(title: String, link: String, pubDate: String, ticker: String, linkTicker: String, enclosure: String) {
        
        let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, Error in
            print (Error as Any)
        }
        let managedContext = container.viewContext
        
        
        let entity = NSEntityDescription.entity(forEntityName: "RSS", in: managedContext)
        let feed = NSManagedObject(entity: entity!, insertInto: managedContext)
        
        feed.setValue(title, forKeyPath: "title")
        feed.setValue(link, forKey: "link")
        feed.setValue(pubDate, forKey: "pubDate")
        feed.setValue(ticker, forKey: "ticker")
        feed.setValue(linkTicker, forKey: "linkTicker")
        feed.setValue(enclosure, forKey: "enclosure")
        
        do {
            try managedContext.save()
            feedsManagedObject.append(feed)
        }catch let error as NSError {
            print (error.userInfo)
        }
    }
}
