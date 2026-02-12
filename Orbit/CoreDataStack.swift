//
//  CoreDataStack.swift
//  Orbit
//
//  Created by Daniele Rolli on 2/11/26.
//

import Foundation
import CoreData

class CoreDataStack {
    
    static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OrbitDataModel")
        
        // Configure store description for encryption
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(FileProtectionType.complete as NSObject,
                                   forKey: NSPersistentStoreFileProtectionKey)
        
        // Enable automatic lightweight migration
        storeDescription?.setOption(true as NSNumber,
                                   forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription?.setOption(true as NSNumber,
                                   forKey: NSInferMappingModelAutomaticallyOption)
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("Core Data store loaded with encryption: \(storeDescription)")
        }
        
        // Configure merge policy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Context
    
    func saveContext(_ context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext
        
        if contextToSave.hasChanges {
            try contextToSave.save()
        }
    }
    
    // MARK: - Batch Delete
    
    func batchDelete<T: NSManagedObject>(entityType: T.Type) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
        
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes,
                                               into: [viewContext])
        }
    }
}
