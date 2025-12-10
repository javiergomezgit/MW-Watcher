//
//  SaveMyTickers.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import CoreData
import UIKit

class SaveTickers {
    var tickerManagedObjectArray: [NSManagedObject] = []
    let entityName = "WatchlistEntity"
    
    func saveTicker(tickerFeatures: TickersFeatures) {
        DispatchQueue.main.async { [self] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
            let tickerObject = NSManagedObject(entity: entity, insertInto: managedContext)
            
            tickerObject.setValue(tickerFeatures.ticker, forKey: "ticker")
            tickerObject.setValue(tickerFeatures.nameTicker, forKey: "nameCompany")
            tickerObject.setValue(tickerFeatures.imageTickerName, forKey: "imageCompanyName")
            
            guard let imageToData = tickerFeatures.imageTicker.pngData() else {
                print("jpg error")
                return
            }
            tickerObject.setValue(imageToData, forKey: "imageCompany")
            
            do {
                try managedContext.save()
                tickerManagedObjectArray.append(tickerObject)
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
        }
    }
    
    func deleteAllTickers() {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let managedContext = appDelegate.persistentContainer.viewContext

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: self.entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try managedContext.execute(deleteRequest)
                try managedContext.save()
                print("✅ All tickers deleted successfully")
            } catch {
                print("❌ Failed to delete all tickers: \(error)")
            }
        }
    }

    
    func deleteTicker(tickerFeatures: TickersFeatures) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let managedContext = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: self.entityName)
            
            // Match by any property you care about
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "ticker == %@", tickerFeatures.ticker),
                NSPredicate(format: "nameCompany == %@", tickerFeatures.nameTicker),
                NSPredicate(format: "imageCompanyName == %@", tickerFeatures.imageTickerName)
            ])

            do {
                let results = try managedContext.fetch(fetchRequest)

                for object in results {
                    managedContext.delete(object)
                }

                if managedContext.hasChanges {
                    try managedContext.save()
                }
            } catch {
                print("Failed to delete ticker: \(error)")
            }
        }
    }
    
    func loadTickers() -> [TickersFeatures] {
        
        var tickerItems : [TickersFeatures] = []
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        fetchRequest.returnsDistinctResults = true
        fetchRequest.propertiesToFetch = ["ticker"]
        
        var seenTickers = Set<String>()
        
        do {
            tickerManagedObjectArray = try managedContext.fetch(fetchRequest)
            
            for tickerObject in tickerManagedObjectArray {
                var imageFromData = UIImage()
                let ticker = tickerObject.value(forKey: "ticker") as! String
                
                // ---- MEMORY-LEVEL GUARD (optional but bullet-proof) ----
                            guard seenTickers.insert(ticker).inserted else { continue }
                            // ---------------------------------------------------------
                
                
                var name = tickerObject.value(forKey: "nameCompany") as? String
                let imageName = tickerObject.value(forKey: "imageCompanyName") as? String ?? ticker
                if name == nil {
                    name = "n/a"
                }
                if let imageData = tickerObject.value(forKey: "imageCompany") as? Data {
                    do {
                        if let image = UIImage(data: imageData) {
                            imageFromData = image
                        } else {
                            imageFromData = UIImage(named: "mw-logo")!
                        }
                    }

                } else {
                    imageFromData = UIImage(named: "mw-logo")!
                }

                let tickerItem = TickersFeatures(ticker: ticker, nameTicker: name!, imageTicker: imageFromData, imageTickerName: imageName)
                tickerItems.append(tickerItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        let tickersSortedItems = tickerItems.sorted{ $0.ticker < $1.ticker }
        
        return tickersSortedItems
        
    }
}
