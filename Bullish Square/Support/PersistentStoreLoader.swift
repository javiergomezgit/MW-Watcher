//
//  PersistentStoreLoader.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/29/26.
//

import CoreData
import Foundation

///Loads the Core Data stores without ever taking the app down.
///
///AppDelegate used to fatalError on any load failure, so a lightweight migration that failed,
///a corrupt SQLite file, or a disk too full to open the store became a crash on every launch
///with no way out short of deleting the app. 2.0.6 shipped a model change, which made that
///path live.
///
///Kept free of Firebase so the recovery can be exercised outside the app. Reporting is
///handed in by the caller.
enum PersistentStoreLoader {

    enum Outcome: Equatable {
        ///The store opened, migrating first if the model changed.
        case loaded
        ///The store itself was unusable. It was set aside and an empty one created.
        case recoveredWithFreshStore
        ///Nothing on disk could be opened. The file was left alone; nothing persists this
        ///session, and the next launch tries the real store again.
        case inMemoryFallback
    }

    ///Relies on `shouldAddStoreAsynchronously` being false, its default, so the load handler
    ///has run by the time `loadPersistentStores` returns.
    static func load(_ container: NSPersistentContainer,
                     report: (NSError, String) -> Void) -> Outcome {
        guard let firstError = loadStores(container) else { return .loaded }
        report(firstError, "initial load")

        //Only a store that is itself broken gets replaced. A full disk, a locked device or a
        //permissions problem means the data is fine but unreadable right now, and replacing it
        //would destroy a user's watchlists over something that clears on its own.
        if isUnusableStoreError(firstError),
           let storeURL = container.persistentStoreDescriptions.first?.url {
            setAside(storeAt: storeURL)
            guard let retryError = loadStores(container) else { return .recoveredWithFreshStore }
            report(retryError, "fresh store")
        }

        let memoryDescription = NSPersistentStoreDescription()
        memoryDescription.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [memoryDescription]

        if let memoryError = loadStores(container) {
            //Effectively unreachable. The store wrappers all save and fetch inside do/catch,
            //so even a container with no store degrades to empty screens rather than a crash.
            report(memoryError, "in-memory store")
        }
        return .inMemoryFallback
    }

    private static func loadStores(_ container: NSPersistentContainer) -> NSError? {
        var failure: NSError?
        container.loadPersistentStores { _, error in
            if let error {
                failure = error as NSError
            }
        }
        return failure
    }

    // MARK: - Classifying the failure

    ///True only when the store file itself cannot be used. Internal rather than private so the
    ///classification can be checked directly against constructed errors.
    ///
    ///The whole chain is inspected, and any transient cause wins. A migration that ran out of
    ///disk space reports NSMigrationError at the top with SQLITE_FULL underneath, and treating
    ///that as a broken store is exactly how data gets lost.
    static func isUnusableStoreError(_ error: NSError) -> Bool {
        let chain = errorChain(error)
        if chain.contains(where: isTransient) { return false }
        return chain.contains(where: isStoreDamage)
    }

    private static func isStoreDamage(_ error: NSError) -> Bool {
        switch error.domain {
        case NSCocoaErrorDomain:
            let codes: Set<Int> = [
                NSPersistentStoreIncompatibleVersionHashError,
                NSPersistentStoreIncompatibleSchemaError,
                NSMigrationError,
                NSMigrationConstraintViolationError,
                NSMigrationMissingSourceModelError,
                NSMigrationMissingMappingModelError,
                NSMigrationManagerSourceStoreError,
                NSMigrationManagerDestinationStoreError,
                NSEntityMigrationPolicyError,
                NSInferredMappingModelError,
                NSFileReadCorruptFileError
            ]
            return codes.contains(error.code)
        case NSSQLiteErrorDomain:
            //SQLITE_CORRUPT, SQLITE_NOTADB: the file is there but is not a usable database.
            return [11, 26].contains(error.code)
        default:
            return false
        }
    }

    private static func isTransient(_ error: NSError) -> Bool {
        switch error.domain {
        case NSCocoaErrorDomain:
            let codes: Set<Int> = [
                NSFileWriteOutOfSpaceError,
                NSFileReadNoPermissionError,
                NSFileWriteNoPermissionError,
                NSFileWriteVolumeReadOnlyError
            ]
            return codes.contains(error.code)
        case NSSQLiteErrorDomain:
            //PERM, BUSY, LOCKED, IOERR, FULL, CANTOPEN, AUTH. CANTOPEN and AUTH are what a store
            //behind data protection reports when the app launches before first unlock.
            return [3, 5, 6, 10, 13, 14, 23].contains(error.code)
        case NSPOSIXErrorDomain:
            //EPERM, EACCES, ENOSPC, EROFS
            return [1, 13, 28, 30].contains(error.code)
        default:
            return false
        }
    }

    ///Follows both the single underlying error and Core Data's list of detailed errors. Depth
    ///is capped because nothing guarantees the graph is acyclic.
    private static func errorChain(_ error: NSError, depth: Int = 0) -> [NSError] {
        guard depth < 8 else { return [error] }

        var chain = [error]
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            chain += errorChain(underlying, depth: depth + 1)
        }
        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for detail in detailed {
                chain += errorChain(detail, depth: depth + 1)
            }
        }
        return chain
    }

    // MARK: - Setting the old store aside

    ///Moves the SQLite file and its -wal and -shm companions aside rather than deleting them,
    ///so the data still exists if it ever needs recovering. Only the first unreadable store is
    ///kept. If one is already set aside, the new failure is removed instead, which bounds the
    ///disk this can use and keeps the copy most likely to hold the user's real data.
    private static func setAside(storeAt storeURL: URL) {
        let fileManager = FileManager.default
        let backupPath = storeURL.path + ".unreadable"
        let keepExistingBackup = fileManager.fileExists(atPath: backupPath)

        for suffix in ["", "-wal", "-shm"] {
            let sourcePath = storeURL.path + suffix
            guard fileManager.fileExists(atPath: sourcePath) else { continue }

            do {
                if keepExistingBackup {
                    try fileManager.removeItem(atPath: sourcePath)
                } else {
                    try fileManager.moveItem(atPath: sourcePath, toPath: backupPath + suffix)
                }
            } catch let error as NSError {
                print("Could not set aside \(sourcePath). \(error), \(error.userInfo)")
            }
        }
    }
}
