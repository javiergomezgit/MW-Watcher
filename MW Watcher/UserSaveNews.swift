//
//  SaveHeadlines.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/24/21.
//

import CoreData
import UIKit

class UserSaveNews {
    
    var newsManagedObjectArray: [NSManagedObject] = []
    let entityName = "SavedNewsEntity"
    
    func saveNews(headline: String, date: String, link: String) -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return false }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let headlineObject = NSManagedObject(entity: entity, insertInto: managedContext)
        
        headlineObject.setValue(headline, forKey: "headline")
        headlineObject.setValue(date, forKey: "date")
        headlineObject.setValue(link, forKey: "link")
        
        do {
            try managedContext.save()
            newsManagedObjectArray.append(headlineObject)
            return true
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return false
        }
    }
    
    func deleteNews(headline: String, date: String, deleteAll: Bool) {
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
                newsManagedObjectArray = try managedContext.fetch(fetchRequest)

                for newsManagedObject in newsManagedObjectArray {
                    let localHeadline = newsManagedObject.value(forKey: "headline") as! String
                    //let date = headlineManagedObject.value(forKey: "date") as! String
                    if localHeadline == headline {
                        managedContext.delete(newsManagedObject)
                        try managedContext.save()
                    }
                }
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }

    }
    
    func loadNews() -> [UserSavedNewsItem] {
        var newsItemArray : [UserSavedNewsItem] = []
        
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            newsManagedObjectArray = try managedContext.fetch(fetchRequest)

            for newsManagedObject in newsManagedObjectArray {
                let headline = newsManagedObject.value(forKey: "headline") as! String
                let date = newsManagedObject.value(forKey: "date") as! String
                let link = newsManagedObject.value(forKey: "link") as! String
                
                let newsItem = UserSavedNewsItem.init(headline: headline, link: link, pubDate: date)
                newsItemArray.append(newsItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return newsItemArray
    }
}
