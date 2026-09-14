//
//  WatchlistStore.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/14/26.
//

import CoreData
import UIKit

///The watchlists themselves - their names, order, and which one is showing.
///
///Tickers live in `WatchlistEntity` keyed by `watchlistID`; this is the list those ids point
///at. Local only for now: `WatchlistSyncService` mirrors it to Firestore once the sync work
///lands, and Core Data becomes that user's cache rather than the record.
final class WatchlistStore {

    static let shared = WatchlistStore()

    private init() {}

    private let entityName = "WatchlistMetaEntity"

    ///Matches the id `WatchlistSyncService` writes to, so the two agree from the start.
    static let defaultWatchlistID = WatchlistSyncService.defaultWatchlistID
    static let defaultWatchlistName = "My Watchlist"

    struct Watchlist: Equatable {
        let id: String
        let name: String
        let order: Int
    }

    private var ownerUID: String { WatchlistSyncService.currentOwnerUID }

    private var managedContext: NSManagedObjectContext? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }

    // MARK: - Reading

    func allWatchlists() -> [Watchlist] {
        guard let managedContext else { return [] }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "ownerUID == %@", ownerUID)

        do {
            let objects = try managedContext.fetch(fetchRequest)
            let lists: [Watchlist] = objects.compactMap { object in
                //A row with no id cannot be pointed at by any ticker, so it is not a list.
                guard let id = object.value(forKey: "watchlistID") as? String, !id.isEmpty else { return nil }
                return Watchlist(
                    id: id,
                    name: object.value(forKey: "name") as? String ?? Self.defaultWatchlistName,
                    order: object.value(forKey: "order") as? Int ?? 0
                )
            }
            return lists.sorted { $0.order == $1.order ? $0.name < $1.name : $0.order < $1.order }
        } catch let error as NSError {
            print("Could not fetch watchlists. \(error), \(error.userInfo)")
            return []
        }
    }

    func watchlist(id: String) -> Watchlist? {
        allWatchlists().first { $0.id == id }
    }

    // MARK: - Active selection

    ///Per owner, so signing in as someone else does not inherit the previous selection.
    private var activeKey: String { "activeWatchlistID_\(ownerUID)" }

    var activeWatchlistID: String {
        get {
            let stored = UserDefaults.standard.string(forKey: activeKey)
            //A stored id whose list has since been deleted would show an empty watchlist
            //with no way back, so fall back to whatever exists.
            if let stored, allWatchlists().contains(where: { $0.id == stored }) {
                return stored
            }
            return allWatchlists().first?.id ?? Self.defaultWatchlistID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: activeKey)
        }
    }

    var activeWatchlistName: String {
        watchlist(id: activeWatchlistID)?.name ?? Self.defaultWatchlistName
    }

    // MARK: - Writing

    ///Called on launch and after sign-in. Existing installs have tickers but no list to hang
    ///them on, so the default is created and those tickers are adopted into it.
    @discardableResult
    func ensureDefaultExists() -> Watchlist {
        if let existing = watchlist(id: Self.defaultWatchlistID) { return existing }
        if let anyList = allWatchlists().first { return anyList }

        let created = create(name: Self.defaultWatchlistName, id: Self.defaultWatchlistID)
        adoptOrphanedTickers(into: Self.defaultWatchlistID)
        return created ?? Watchlist(id: Self.defaultWatchlistID, name: Self.defaultWatchlistName, order: 0)
    }

    @discardableResult
    func create(name: String, id: String = UUID().uuidString) -> Watchlist? {
        guard let managedContext,
              let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) else { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? Self.defaultWatchlistName : trimmed
        let order = (allWatchlists().map(\.order).max() ?? -1) + 1

        let object = NSManagedObject(entity: entity, insertInto: managedContext)
        object.setValue(id, forKey: "watchlistID")
        object.setValue(finalName, forKey: "name")
        object.setValue(order, forKey: "order")
        object.setValue(ownerUID, forKey: "ownerUID")

        do {
            try managedContext.save()
            return Watchlist(id: id, name: finalName, order: order)
        } catch let error as NSError {
            print("Could not create watchlist. \(error), \(error.userInfo)")
            return nil
        }
    }

    func rename(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let managedContext else { return }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "ownerUID == %@ AND watchlistID == %@", ownerUID, id)

        do {
            for object in try managedContext.fetch(fetchRequest) {
                object.setValue(trimmed, forKey: "name")
            }
            if managedContext.hasChanges { try managedContext.save() }
        } catch let error as NSError {
            print("Could not rename watchlist. \(error), \(error.userInfo)")
        }
    }

    ///Deleting takes the list's tickers with it. Refuses to remove the last one - there has
    ///to be somewhere for the Watchlist tab to land.
    @discardableResult
    func delete(id: String) -> Bool {
        guard allWatchlists().count > 1, let managedContext else { return false }

        let metaRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        metaRequest.predicate = NSPredicate(format: "ownerUID == %@ AND watchlistID == %@", ownerUID, id)

        let tickerRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchlistEntity")
        tickerRequest.predicate = NSPredicate(format: "ownerUID == %@ AND watchlistID == %@", ownerUID, id)

        do {
            for object in try managedContext.fetch(metaRequest) { managedContext.delete(object) }
            for object in try managedContext.fetch(tickerRequest) { managedContext.delete(object) }
            if managedContext.hasChanges { try managedContext.save() }
        } catch let error as NSError {
            print("Could not delete watchlist. \(error), \(error.userInfo)")
            return false
        }

        if activeWatchlistID == id {
            activeWatchlistID = allWatchlists().first?.id ?? Self.defaultWatchlistID
        }
        return true
    }

    // MARK: - Migration

    ///Tickers saved before watchlists existed carry no owner and no list. Claim them for the
    ///default rather than leaving them invisible behind a scoped fetch.
    private func adoptOrphanedTickers(into watchlistID: String) {
        guard let managedContext else { return }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchlistEntity")
        fetchRequest.predicate = NSPredicate(format: "watchlistID == nil OR watchlistID == %@", "")

        do {
            let orphans = try managedContext.fetch(fetchRequest)
            guard !orphans.isEmpty else { return }

            for object in orphans {
                object.setValue(watchlistID, forKey: "watchlistID")
                object.setValue(ownerUID, forKey: "ownerUID")
            }
            if managedContext.hasChanges { try managedContext.save() }
            print("Adopted \(orphans.count) existing tickers into \(watchlistID)")
        } catch let error as NSError {
            print("Could not adopt existing tickers. \(error), \(error.userInfo)")
        }
    }
}
