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

    func loadContainers() {
        //let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.xcdatamodeld")
        let storeURL = AppGroup.facts.containerURL.appendingPathComponent("SavingFeeds.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        let container = NSPersistentContainer(name: "SavingFeeds")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, Error in
            print (Error)
            print (storeDescription)
            print (storeDescription.description)
        }
        let managedContext = container.viewContext
        
//        let entity = NSEntityDescription.entity(forEntityName: "RSS", in: managedContext)
//        print (entity)
//        let feed = NSManagedObject(entity: entity!, insertInto: managedContext)
//        print (feed)
            
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RSS")

        do {
            feedsManagedObject = try managedContext.fetch(fetchRequest)
            print (feedsManagedObject.count)

            for feed in feedsManagedObject {
                
                print (feedsManagedObject.count)
                print (feed)
            
                
                let title = feed.value(forKey: "title") as! String
                let link = feed.value(forKey: "link") as! String
                let pubDate = feed.value(forKey: "pubDate") as! String
                let ticker = feed.value(forKey: "ticker") as! String
                let linkTicker = feed.value(forKey: "linkTicker") as! String
                
//                let imageData = feed.value(forKey: "image") as! Data
//                var imageFromData = UIImage()
//                do {
//                    if let image = UIImage(data: imageData) {
//                        imageFromData = image
//                    } else {
//                        imageFromData = UIImage(named: "mw-logo")!
//                    }
//                }
                
                
//                let feedItem = RSSItemWithImages.init(title: title, link: link, pubDate: pubDate, ticker: ticker, linkTicker: linkTicker, rssImage: imageFromData)
//
//                feedItems.append(feedItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
     
        
        
        
                
        
     
    }
}


//class SaveFeedsWidget {
//    var feedsManagedObject: [NSManagedObject] = []
//    let entityName = "RSS"
//
//
//    static let shared = SaveFeedsWidget()
//
//        private init() {}
//
//        var managedObjectContext: NSManagedObjectContext {
//            return self.persistentContainer.viewContext
//        }
//
//        var workingContext: NSManagedObjectContext {
//            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
//            context.parent = self.managedObjectContext
//            return context
//        }
//
//        // MARK: - Core Data stack
////    let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.mw-watcher")!
////    let storeURL = containerURL.appendingPathComponent("DataModel.sqlite")
////    let description = NSPersistentStoreDescription(url: storeURL)
////
////    let container = NSPersistentContainer(name: "RSS")
////    container.persistentStoreDescriptions = [description]
////    container.loadPersistentStores { storeDescription, Error in
////        print (Error)
////        print (storeDescription)
////        print (storeDescription.description)
////    }
//
//
//
//        lazy var persistentContainer: NSPersistentContainer = {
//            let container = NSPersistentContainer(name: "RSS")
//            container.loadPersistentStores(completionHandler: { storeDescription, error in
//                if let error = error as NSError? {
//                    print (error)
//                    print (storeDescription)
//                } else {
//                    print (storeDescription.description)
//                }
//            })
//            return container
//        }()
//
//        // MARK: - Core Data Saving support
//
//        func saveContext() {
//            self.managedObjectContext.performAndWait {
//                if self.managedObjectContext.hasChanges {
//                    do {
//                        try self.managedObjectContext.save()
//                        print (managedObjectContext)
//                        print ("saved")
//                    } catch {
//                        print (error)
//                    }
//                }
//            }
//        }
//
//    func saveWorkingContext(context: NSManagedObjectContext) {
//        do {
//            try context.save()
//            print ("saved")
//            saveContext()
//        } catch (let error) {
//            print (error)
//
//        }
//    }
//}

    
    
//    func saveRSS(title: String, link: String, pubDate: String, ticker: String, linkTicker: String, image: UIImage ) {
//
//
//
//        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
//        let managedContext = appDelegate.persistentContainer.viewContext
//        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
//        let feed = NSManagedObject(entity: entity, insertInto: managedContext)
//
//        feed.setValue(title, forKeyPath: "title")
//        feed.setValue(link, forKey: "link")
//        feed.setValue(pubDate, forKey: "pubDate")
//        feed.setValue(ticker, forKey: "ticker")
//        feed.setValue(linkTicker, forKey: "linkTicker")
//
//        guard let imageToData = image.jpegData(compressionQuality: 1) else {
//            print("jpg error")
//            return
//            }
//        feed.setValue(imageToData, forKey: "image")
//
//        do {
//            try managedContext.save()
//            feedsManagedObject.append(feed)
//        } catch let error as NSError {
//            print("Could not save. \(error), \(error.userInfo)")
//        }
//    }
//
//}





