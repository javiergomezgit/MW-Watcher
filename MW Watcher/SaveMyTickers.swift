//
//  SaveMyTickers.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/25/21.
//

import CoreData
import UIKit

class SaveMyTickers {
    var tickerManagedObject: [NSManagedObject] = []
    let entityName = "MyTickers"
    
    func saveTicker(ticker: String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let tickerObject = NSManagedObject(entity: entity, insertInto: managedContext)
        
        tickerObject.setValue(ticker, forKey: "ticker")
        
        do {
            try managedContext.save()
            tickerManagedObject.append(tickerObject)
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

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
                tickerManagedObject = try managedContext.fetch(fetchRequest)

                for tickerObject in tickerManagedObject {
                    let localTicker = tickerObject.value(forKey: "ticker") as! String
                    if localTicker == ticker {
                        managedContext.delete(tickerObject)
                        try managedContext.save()
                    }
                }
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }

    }
    
    func loadTickers() -> [String] {
        
        var tickerItems : [String] = []
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            tickerManagedObject = try managedContext.fetch(fetchRequest)

            for tickerObject in tickerManagedObject {
                let ticker = tickerObject.value(forKey: "ticker") as! String
                tickerItems.append(ticker)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return tickerItems
    }
}
