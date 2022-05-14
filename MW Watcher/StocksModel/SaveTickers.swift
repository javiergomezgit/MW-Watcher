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
    
    func deleteTicker(tickerFeatures: TickersFeatures) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            tickerManagedObjectArray = try managedContext.fetch(fetchRequest)
            
            for tickerManagedObject in tickerManagedObjectArray {
                let localTicker = tickerManagedObject.value(forKey: "ticker") as! String
                let localNameCompany = tickerManagedObject.value(forKey: "nameCompany") as! String
                let localImageData = tickerManagedObject.value(forKey: "imageCompany") as! Data
                let localImage = tickerFeatures.imageTicker.pngData()
                
                if localTicker == tickerFeatures.ticker {
                    managedContext.delete(tickerManagedObject)
                    try managedContext.save()
                }
                if localNameCompany == tickerFeatures.nameTicker {
                    managedContext.delete(tickerManagedObject)
                    try managedContext.save()
                }
                if localImageData == localImage {
                    managedContext.delete(tickerManagedObject)
                    try managedContext.save()
                }
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    func loadTickers() -> [TickersFeatures] {
        
        var tickerItems : [TickersFeatures] = []
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            tickerManagedObjectArray = try managedContext.fetch(fetchRequest)
            
            for tickerObject in tickerManagedObjectArray {
                var imageFromData = UIImage()
                let ticker = tickerObject.value(forKey: "ticker") as! String
                var name = tickerObject.value(forKey: "nameCompany") as? String
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

                let tickerItem = TickersFeatures(ticker: ticker, nameTicker: name!, imageTicker: imageFromData)
                tickerItems.append(tickerItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        let tickersSortedItems = tickerItems.sorted{ $0.ticker < $1.ticker }
        
        return tickersSortedItems
    }
}
