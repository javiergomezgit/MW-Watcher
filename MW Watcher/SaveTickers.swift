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
    
    func saveTicker(ticker: String, nameCompany: String, imageCompany: UIImage) {
        DispatchQueue.main.async { [self] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
            let tickerObject = NSManagedObject(entity: entity, insertInto: managedContext)
            
            tickerObject.setValue(ticker, forKey: "ticker")
            tickerObject.setValue(nameCompany, forKey: "nameCompany")
            
            guard let imageToData = imageCompany.jpegData(compressionQuality: 1) else {
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

    //TODO: Add delete image and delete name company, not only ticker
    func deleteTickers(ticker: String, deleteAll: Bool) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        
        if deleteAll {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try managedContext.execute(deleteRequest)
                try managedContext.save()
            } catch {
                print ("there is an error")
            }
        } else {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                tickerManagedObjectArray = try managedContext.fetch(fetchRequest)

                for tickerManagedObject in tickerManagedObjectArray {
                    let localTicker = tickerManagedObject.value(forKey: "ticker") as! String
                    if localTicker == ticker {
                        managedContext.delete(tickerManagedObject)
                        try managedContext.save()
                    }
                }
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }

    }
    
    func loadTickers() -> [Tickers] {
        
        var tickerItems : [Tickers] = []
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            tickerManagedObjectArray = try managedContext.fetch(fetchRequest)

            for tickerObject in tickerManagedObjectArray {
                var imageFromData = UIImage()
                let ticker = tickerObject.value(forKey: "ticker") as! String
                let name = tickerObject.value(forKey: "nameCompany") as! String
                let imageData = tickerObject.value(forKey: "imageCompany") as! Data
                
                do {
                    if let image = UIImage(data: imageData) {
                        imageFromData = image
                    } else {
                        imageFromData = UIImage(named: "mw-logo")!
                    }
                }
                
                let tickerItem = Tickers(ticker: [ticker : ValueTickers(marketPrice: nil, previousPrice: nil, nameCompany: name, volume: nil, imageCompany: imageFromData)])
                tickerItems.append(tickerItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return tickerItems
    }
}
