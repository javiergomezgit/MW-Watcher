//
//  SaveMyTickers.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/10/25.
//

import CoreData
import UIKit

class SaveProfileInformation {
    var imageProfileManagedObjectArray: [NSManagedObject] = []
    let entityName = "ProfileEntity"
    
    func saveImageProfile(imageProfile: UIImage) {
        DispatchQueue.main.async { [self] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
            let imageObject = NSManagedObject(entity: entity, insertInto: managedContext)
            
            guard let imageToData = imageProfile.pngData() else {
                print("png error")
                return
            }
            imageObject.setValue(imageToData, forKey: "imageProfile")
            
            do {
                try managedContext.save()
                imageProfileManagedObjectArray.append(imageObject)
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
        }
    }
    
    func loadImageProfile() -> UIImage {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let managedContext = appDelegate!.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)

        var imageFromData = UIImage()
        do {
            imageProfileManagedObjectArray = try managedContext.fetch(fetchRequest)
            for imageObject in imageProfileManagedObjectArray {
                if let imageData = imageObject.value(forKey: "imageProfile") as? Data {
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
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return imageFromData
    }
    
//    func deleteTicker(tickerFeatures: TickersFeatures) {
//        DispatchQueue.main.async {
//            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
//            let managedContext = appDelegate.persistentContainer.viewContext
//            
//            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: self.entityName)
//            
//            // Match by any property you care about
//            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
//                NSPredicate(format: "ticker == %@", tickerFeatures.ticker),
//                NSPredicate(format: "nameCompany == %@", tickerFeatures.nameTicker),
//                NSPredicate(format: "imageCompanyName == %@", tickerFeatures.imageTickerName)
//            ])
//
//            do {
//                let results = try managedContext.fetch(fetchRequest)
//
//                for object in results {
//                    managedContext.delete(object)
//                }
//
//                if managedContext.hasChanges {
//                    try managedContext.save()
//                }
//            } catch {
//                print("Failed to delete ticker: \(error)")
//            }
//        }
//    }
    

}
