//
//  SaveHeadlines.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/24/21.
//

import CoreData
import UIKit

class SaveHeadlines {
    
    var headlinesManagedObject: [NSManagedObject] = []
    let entityName = "News"
    
    func saveHeadlines(headline: String, date: String) -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return false }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let headlineObject = NSManagedObject(entity: entity, insertInto: managedContext)
        
        headlineObject.setValue(headline, forKey: "headline")
        headlineObject.setValue(date, forKey: "date")
        
        do {
            try managedContext.save()
            headlinesManagedObject.append(headlineObject)
            return true
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return false
        }
    }
    
    func deleteHeadlines() {
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
    
    func loadHeadlines() -> [HeadlineItem] {
        var headlineItems : [HeadlineItem] = []
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            headlinesManagedObject = try managedContext.fetch(fetchRequest)

            for headlineManagedObject in headlinesManagedObject {
                let headline = headlineManagedObject.value(forKey: "headline") as! String
                let date = headlineManagedObject.value(forKey: "date") as! String
                
                let headlineItem = HeadlineItem.init(headline: headline, date: date)
                headlineItems.append(headlineItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return headlineItems
    }
}
