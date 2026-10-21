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
///at. For a signed-in user Core Data is the offline copy: every change here is written
///through to the cloud, and `WatchlistSyncService` replaces the copy with the cloud's.
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

        //Not written through. A new phone creates this before the first sync answers, and
        //sending it would overwrite the name the default was given on another phone. The
        //first sync carries it up if the cloud lacks it.
        let created = insert(name: Self.defaultWatchlistName, id: Self.defaultWatchlistID)
        adoptOrphanedTickers(into: Self.defaultWatchlistID)
        return created ?? Watchlist(id: Self.defaultWatchlistID, name: Self.defaultWatchlistName, order: 0)
    }

    @discardableResult
    func create(name: String, id: String = UUID().uuidString) -> Watchlist? {
        guard let created = insert(name: name, id: id) else { return nil }
        WatchlistSyncService.shared.watchlistSaved(created, ownerUID: ownerUID)
        return created
    }

    private func insert(name: String, id: String) -> Watchlist? {
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
            return
        }

        if let renamed = watchlist(id: id) {
            WatchlistSyncService.shared.watchlistSaved(renamed, ownerUID: ownerUID)
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
        WatchlistSyncService.shared.watchlistDeleted(id: id, ownerUID: ownerUID)

        if activeWatchlistID == id {
            activeWatchlistID = allWatchlists().first?.id ?? Self.defaultWatchlistID
        }
        return true
    }

    // MARK: - Cloud sync

    ///The operations below act on one owner's whole set of lists, so they filter on owner
    ///alone. Each takes the owner explicitly: they run on sign-in and sign-out, when the
    ///signed-in user is changing and `currentOwnerUID` may already be the next one.

    ///Every list the owner has, with its tickers, in the shape the cloud holds.
    func snapshot(ownerUID owner: String) -> [CloudWatchlist] {
        guard let managedContext else { return [] }

        let metaRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        metaRequest.predicate = NSPredicate(format: "ownerUID == %@", owner)
        let tickerRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchlistEntity")
        tickerRequest.predicate = NSPredicate(format: "ownerUID == %@", owner)

        do {
            var tickersByList = [String: [CloudTicker]]()
            for object in try managedContext.fetch(tickerRequest) {
                guard let watchlistID = object.value(forKey: "watchlistID") as? String,
                      let ticker = object.value(forKey: "ticker") as? String else { continue }
                //The same ticker twice in one list is a local duplicate, never two entries.
                guard !(tickersByList[watchlistID] ?? []).contains(where: { $0.ticker == ticker }) else { continue }
                tickersByList[watchlistID, default: []].append(
                    CloudTicker(ticker: ticker, nameCompany: object.value(forKey: "nameCompany") as? String ?? "n/a"))
            }

            return try managedContext.fetch(metaRequest).compactMap { object in
                guard let id = object.value(forKey: "watchlistID") as? String, !id.isEmpty else { return nil }
                return CloudWatchlist(id: id,
                                      name: object.value(forKey: "name") as? String ?? Self.defaultWatchlistName,
                                      order: object.value(forKey: "order") as? Int ?? 0,
                                      tickers: (tickersByList[id] ?? []).sorted { $0.ticker < $1.ticker })
            }.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        } catch let error as NSError {
            print("Could not read the watchlists to sync. \(error), \(error.userInfo)")
            return []
        }
    }

    ///Makes the owner's lists exactly `lists`. A ticker already on the device keeps its logo;
    ///one arriving from another phone has none, and the watchlist fetches it as for any new
    ///row. Returns whether anything changed, so an unchanged sync does not reload the screen.
    @discardableResult
    func replaceLocal(ownerUID owner: String, with lists: [CloudWatchlist]) -> Bool {
        guard let managedContext,
              let metaEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext),
              let tickerEntity = NSEntityDescription.entity(forEntityName: "WatchlistEntity", in: managedContext) else { return false }

        let metaRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        metaRequest.predicate = NSPredicate(format: "ownerUID == %@", owner)
        let tickerRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchlistEntity")
        tickerRequest.predicate = NSPredicate(format: "ownerUID == %@", owner)

        do {
            var metas = [String: NSManagedObject]()
            for object in try managedContext.fetch(metaRequest) {
                let id = object.value(forKey: "watchlistID") as? String ?? ""
                //A second row for the same id, or one with none, is removed as a duplicate.
                if id.isEmpty || metas[id] != nil {
                    managedContext.delete(object)
                } else {
                    metas[id] = object
                }
            }

            var rows = [String: NSManagedObject]()
            for object in try managedContext.fetch(tickerRequest) {
                let key = "\(object.value(forKey: "watchlistID") as? String ?? "")|\(object.value(forKey: "ticker") as? String ?? "")"
                if rows[key] != nil {
                    managedContext.delete(object)
                } else {
                    rows[key] = object
                }
            }

            for list in lists {
                let meta = metas.removeValue(forKey: list.id) ?? {
                    let object = NSManagedObject(entity: metaEntity, insertInto: managedContext)
                    object.setValue(list.id, forKey: "watchlistID")
                    object.setValue(owner, forKey: "ownerUID")
                    return object
                }()
                if meta.value(forKey: "name") as? String != list.name { meta.setValue(list.name, forKey: "name") }
                if meta.value(forKey: "order") as? Int != list.order { meta.setValue(list.order, forKey: "order") }

                for entry in list.tickers {
                    if let row = rows.removeValue(forKey: "\(list.id)|\(entry.ticker)") {
                        if row.value(forKey: "nameCompany") as? String != entry.nameCompany {
                            row.setValue(entry.nameCompany, forKey: "nameCompany")
                        }
                        continue
                    }
                    //No logo and an empty logo name: loadTickers reports it unresolved.
                    let row = NSManagedObject(entity: tickerEntity, insertInto: managedContext)
                    row.setValue(entry.ticker, forKey: "ticker")
                    row.setValue(entry.nameCompany, forKey: "nameCompany")
                    row.setValue("", forKey: "imageCompanyName")
                    row.setValue(owner, forKey: "ownerUID")
                    row.setValue(list.id, forKey: "watchlistID")
                }
            }

            //Whatever is left was removed on another phone.
            metas.values.forEach { managedContext.delete($0) }
            rows.values.forEach { managedContext.delete($0) }

            guard managedContext.hasChanges else { return false }
            try managedContext.save()
            return true
        } catch let error as NSError {
            print("Could not apply the synced watchlists. \(error), \(error.userInfo)")
            managedContext.rollback()
            return false
        }
    }

    ///Hands a signed-out person's lists to the account they signed into. A list or ticker
    ///the account already has on the device is dropped rather than duplicated.
    func reassign(fromOwner source: String, toOwner destination: String) {
        guard let managedContext else { return }

        let existing = snapshot(ownerUID: destination)
        let existingIDs = Set(existing.map(\.id))
        let existingTickers = Set(existing.flatMap { list in list.tickers.map { "\(list.id)|\($0.ticker)" } })

        let metaRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        metaRequest.predicate = NSPredicate(format: "ownerUID == %@", source)
        let tickerRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchlistEntity")
        tickerRequest.predicate = NSPredicate(format: "ownerUID == %@", source)

        do {
            for object in try managedContext.fetch(metaRequest) {
                if existingIDs.contains(object.value(forKey: "watchlistID") as? String ?? "") {
                    managedContext.delete(object)
                } else {
                    object.setValue(destination, forKey: "ownerUID")
                }
            }
            for object in try managedContext.fetch(tickerRequest) {
                let key = "\(object.value(forKey: "watchlistID") as? String ?? "")|\(object.value(forKey: "ticker") as? String ?? "")"
                if existingTickers.contains(key) {
                    managedContext.delete(object)
                } else {
                    object.setValue(destination, forKey: "ownerUID")
                }
            }
            if managedContext.hasChanges { try managedContext.save() }
        } catch let error as NSError {
            print("Could not move the signed-out watchlists into the account. \(error), \(error.userInfo)")
            managedContext.rollback()
        }
    }

    ///Sign-out. The account's lists stay in the cloud, so the device keeps no copy of them.
    func removeLocal(ownerUID owner: String) {
        guard let managedContext else { return }

        do {
            for entity in [entityName, "WatchlistEntity"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                request.predicate = NSPredicate(format: "ownerUID == %@", owner)
                for object in try managedContext.fetch(request) { managedContext.delete(object) }
            }
            if managedContext.hasChanges { try managedContext.save() }
        } catch let error as NSError {
            print("Could not remove the signed-out account's watchlists. \(error), \(error.userInfo)")
            managedContext.rollback()
        }
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
