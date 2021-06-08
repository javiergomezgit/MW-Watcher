//
//  SaveFeeds.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/11/21.
//


import CoreData
import UIKit

class SystemSaveNews {
    
    var newsManagedObjectArray: [NSManagedObject] = []
    let entityName = "LiveNewsEntity"
    
    func systemSaveNews(headline: String, pubDate: String, image: UIImage ) {
    
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let newsManagedObject = NSManagedObject(entity: entity, insertInto: managedContext)
      
        newsManagedObject.setValue(headline, forKeyPath: "headline")
        newsManagedObject.setValue(pubDate, forKey: "pubDate")
        
        guard let imageToData = image.jpegData(compressionQuality: 1) else {
            print("jpg error")
            return
            }
        
        newsManagedObject.setValue(imageToData, forKey: "image")

        do {
            try managedContext.save()
            newsManagedObjectArray.append(newsManagedObject)
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func systemDeleteNews() {
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
    
    func systemLoadNews() -> [SystemSavedNewsItem] {
        var newsItemArray : [SystemSavedNewsItem] = []
        
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let managedContext = appDelegate!.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            newsManagedObjectArray = try managedContext.fetch(fetchRequest)
            print (newsManagedObjectArray.count)

            for newsManagedObject in newsManagedObjectArray {
                var imageFromData = UIImage()

                let headline = newsManagedObject.value(forKey: "headline") as! String
                let pubDate = newsManagedObject.value(forKey: "pubDate") as! String
                let imageData = newsManagedObject.value(forKey: "image") as! Data
                do {
                    if let image = UIImage(data: imageData) {
                        imageFromData = image
                    } else {
                        imageFromData = UIImage(named: "mw-logo")!
                    }
                }
                
                let newsItem = SystemSavedNewsItem.init(headline: headline, pubDate: pubDate, image: imageFromData)
                newsItemArray.append(newsItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return newsItemArray
            
    }
   
}
