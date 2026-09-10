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

    
    //Deletes by ticker only. This used to be an OR predicate across ticker / nameCompany /
    //imageCompanyName, and because callers passed the literal "mw-logo" as imageCompanyName,
    //removing one stock deleted every row whose logo had not been fetched yet.
    func deleteTicker(ticker: String) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let managedContext = appDelegate.persistentContainer.viewContext

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: self.entityName)
            fetchRequest.predicate = NSPredicate(format: "ticker == %@", ticker)

            do {
                let results = try managedContext.fetch(fetchRequest)

                for object in results {
                    managedContext.delete(object)
                }

                if managedContext.hasChanges {
                    try managedContext.save()
                }
            } catch {
                print("Failed to delete ticker \(ticker): \(error)")
            }
        }
    }

    //Updates an existing row's logo in place. Replaces the old delete-then-reinsert pattern,
    //which relied on the "mw-logo" sentinel and could drop the ticker entirely.
    func updateTickerLogo(ticker: String, image: UIImage, imageName: String) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            let managedContext = appDelegate.persistentContainer.viewContext

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: self.entityName)
            fetchRequest.predicate = NSPredicate(format: "ticker == %@", ticker)

            guard let imageData = image.pngData() else {
                print("Could not encode logo for \(ticker)")
                return
            }

            do {
                let results = try managedContext.fetch(fetchRequest)
                guard !results.isEmpty else { return } //row was removed meanwhile

                for object in results {
                    object.setValue(imageData, forKey: "imageCompany")
                    object.setValue(imageName, forKey: "imageCompanyName")
                }

                if managedContext.hasChanges {
                    try managedContext.save()
                }
            } catch {
                print("Failed to update logo for \(ticker): \(error)")
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
        
        //Used to spot rows that never received a real logo, see below
        let placeholder = UIImage(named: "mw-logo") ?? UIImage()
        let placeholderData = placeholder.pngData()
        
        do {
            tickerManagedObjectArray = try managedContext.fetch(fetchRequest)
            
            for tickerObject in tickerManagedObjectArray {
                var imageFromData = UIImage()
                let ticker = tickerObject.value(forKey: "ticker") as! String
                
                // ---- MEMORY-LEVEL GUARD (optional but bullet-proof) ----
                            guard seenTickers.insert(ticker).inserted else { continue }
                            // ---------------------------------------------------------
                
                
                var name = tickerObject.value(forKey: "nameCompany") as? String
                var imageName = tickerObject.value(forKey: "imageCompanyName") as? String ?? ticker
                if name == nil {
                    name = "n/a"
                }
                if let imageData = tickerObject.value(forKey: "imageCompany") as? Data {
                    imageFromData = UIImage(data: imageData) ?? placeholder
                    
                    //A row still holding the bundled placeholder never got a real logo: a failed
                    //fetch used to be recorded as a success, which marked the row resolved for
                    //good. Report it as unresolved so it is retried instead of staying blank.
                    if imageData == placeholderData {
                        imageName = ""
                    }
                } else {
                    imageFromData = placeholder
                    imageName = ""
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
