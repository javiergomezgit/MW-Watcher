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
    
    func saveNews(headline: String, date: String, link: String, author: String, imageNews: UIImage) -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return false }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let headlineObject = NSManagedObject(entity: entity, insertInto: managedContext)
        
        //Never store nil. A zero-size UIImage returns nil here, and that nil blob is what
        //made loadNews trap when the row was read back.
        let imageData = imageNews.pngData() ?? UIImage(named: "mw-logo")?.pngData()
        
        headlineObject.setValue(headline, forKey: "headline")
        headlineObject.setValue(date, forKey: "date")
        headlineObject.setValue(link, forKey: "link")
        headlineObject.setValue(author, forKey: "author")
        headlineObject.setValue(imageData, forKey: "imageNews")
        
        do {
            try managedContext.save()
            newsManagedObjectArray.append(headlineObject)
            return true
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return false
        }
    }
    
    //Just the article links, for the news screens to render bookmark state from.
    func savedLinks() -> Set<String> {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return [] }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            let objects = try managedContext.fetch(fetchRequest)
            return Set(objects.compactMap { $0.value(forKey: "link") as? String })
        } catch let error as NSError {
            print("Could not fetch saved links. \(error), \(error.userInfo)")
            return []
        }
    }
    
    //Returns Bool rather than Bool?: it never produced nil, and both call sites force
    //unwrapped the result.
    //Matches on link. It used to match on headline and ignore its date parameter entirely,
    //so two articles sharing a headline deleted each other.
    func deleteNews(link: String, deleteAll: Bool) -> Bool {
        var success = false
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            //success = false
            return false
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        
        if deleteAll {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try managedContext.execute(deleteRequest)
                try managedContext.save()
                success = true
            } catch {
                print ("there is an error")
                success = false
            }
        } else {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                newsManagedObjectArray = try managedContext.fetch(fetchRequest)
                for newsManagedObject in newsManagedObjectArray {
                    guard let localLink = newsManagedObject.value(forKey: "link") as? String else { continue }
                    if localLink == link {
                        managedContext.delete(newsManagedObject)
                        try managedContext.save()
                    }
                }
                success = true
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
                success = false
            }
        }
        return success
    }
    
    func loadNews() -> [UserSavedNewsItem] {
        var newsItemArray : [UserSavedNewsItem] = []
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return newsItemArray }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        //Rows saved before the image pipeline was fixed can hold a nil blob, and every field
        //here was force cast, so a single bad row crashed the whole Saved News screen.
        let placeholderData = UIImage(named: "mw-logo")?.pngData() ?? Data()
        
        do {
            newsManagedObjectArray = try managedContext.fetch(fetchRequest)

            for newsManagedObject in newsManagedObjectArray {
                //Without a headline or a link the row cannot be shown or opened, so skip it
                guard let headline = newsManagedObject.value(forKey: "headline") as? String,
                      let link = newsManagedObject.value(forKey: "link") as? String else { continue }
                
                let date = newsManagedObject.value(forKey: "date") as? String ?? ""
                let author = newsManagedObject.value(forKey: "author") as? String ?? ""
                let imageData = newsManagedObject.value(forKey: "imageNews") as? Data ?? placeholderData
                
                let newsItem = UserSavedNewsItem(headline: headline, link: link, pubDate: date, author: author, newsImageData: imageData)
                newsItemArray.append(newsItem)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return newsItemArray
    }
}
