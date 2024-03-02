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
let entityName = "LiveNewsEntity"

struct SaveFeedsWidget {
    
    func setUpStoring() -> NSManagedObjectContext {
        let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, Error in
            print (Error as Any)
        }
        let managedContext = container.viewContext
        
        return managedContext
    }

    func loadSavedFeeds() -> [SystemSavedNewsItem] {
                
        var feedItems : [SystemSavedNewsItem] = []
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)

        do {
            feedsManagedObject = try setUpStoring().fetch(fetchRequest)
            print (feedsManagedObject.count)

            for feed in feedsManagedObject {
                let headline = feed.value(forKey: "headline") as! String
                let pubDate = feed.value(forKey: "pubDate") as! String
                let image = feed.value(forKey: "image") as! UIImage
                
                let feedItem = SystemSavedNewsItem.init(headline: headline, pubDate: pubDate, image: image)
                
                feedItems.append(feedItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return feedItems
    }

    
    func deleteSavedFeeds() {

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try setUpStoring().execute(deleteRequest)
            try setUpStoring().save()
        } catch {
            print (error)
        }
        
    }
    func saveOnlineFeeds(title: String, pubDate: String, image: UIImage) {
        
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: setUpStoring())
        let feed = NSManagedObject(entity: entity!, insertInto: setUpStoring())
        
        feed.setValue(title, forKeyPath: "title")
        feed.setValue(pubDate, forKey: "pubDate")
        
        guard let imageToData = image.jpegData(compressionQuality: 1) else {
            print ("error saving")
            return
        }
        feed.setValue(imageToData, forKey: "image")
        
        do {
            try setUpStoring().save()
            feedsManagedObject.append(feed)
        }catch let error as NSError {
            print (error.userInfo)
        }
    }
}
