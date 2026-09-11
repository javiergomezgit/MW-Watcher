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
    
    //Upserts the single profile row. This used to insert a new row on every save and never
    //remove the old one, and loadImageProfile fetched without a sort descriptor and kept
    //whichever row came last, so the avatar was arbitrary among every photo the user had
    //ever set - and each image blob was retained forever.
    func saveImageProfile(imageProfile: UIImage) {
        DispatchQueue.main.async { [self] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
            let managedContext = appDelegate.persistentContainer.viewContext
            
            guard let imageToData = imageProfile.pngData() else {
                print("png error")
                return
            }
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            
            do {
                let existing = try managedContext.fetch(fetchRequest)
                let imageObject: NSManagedObject
                
                if let current = existing.first {
                    imageObject = current
                    //Anything past the first is a leftover from the old insert-only
                    //behaviour, so an existing install collapses to one row on first save.
                    for surplus in existing.dropFirst() {
                        managedContext.delete(surplus)
                    }
                } else {
                    let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
                    imageObject = NSManagedObject(entity: entity, insertInto: managedContext)
                }
                
                imageObject.setValue(imageToData, forKey: "imageProfile")
                try managedContext.save()
                imageProfileManagedObjectArray = [imageObject]
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
        }
    }
    
    //Returns a zero-sized UIImage when nothing is stored. SettingsController tests
    //size.width == 0 to decide whether to seed the default avatar, so that stays.
    func loadImageProfile() -> UIImage {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return UIImage() }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            imageProfileManagedObjectArray = try managedContext.fetch(fetchRequest)
            guard let imageObject = imageProfileManagedObjectArray.first else { return UIImage() }
            guard let imageData = imageObject.value(forKey: "imageProfile") as? Data else {
                return UIImage(named: "mw-logo") ?? UIImage()
            }
            return UIImage(data: imageData) ?? UIImage(named: "mw-logo") ?? UIImage()
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return UIImage()
        }
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
