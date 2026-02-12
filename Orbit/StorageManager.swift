//
//  StorageManager.swift
//  Orbit
//
//  Manages encrypted storage of ring data
//

import Foundation
import CoreData

class StorageManager {
    
    private let coreDataStack = CoreDataStack.shared
    private let fileManager = FileManager.default
    
    // Legacy storage paths for migration
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var legacyDataDirectory: URL {
        documentsDirectory.appendingPathComponent("RingData", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    init() {
        migrateFromLegacyStorageIfNeeded()
    }
    
    // MARK: - Migration from Legacy JSON Storage
    
    private func migrateFromLegacyStorageIfNeeded() {
        guard fileManager.fileExists(atPath: legacyDataDirectory.path) else {
            return
        }
        
        print("Legacy data directory found, attempting migration...")
        
        Task {
            do {
                try await migrateLegacyData()
                print("Legacy data migration completed successfully")
            } catch {
                print("Legacy data migration failed: \(error)")
            }
        }
    }
    
    private func migrateLegacyData() async throws {
        // Load all legacy JSON data
        let heartRate: [HeartRateSample] = (try? await loadLegacyJSON(filename: "heartrate.json")) ?? []
        let stress: [StressSample] = (try? await loadLegacyJSON(filename: "stress.json")) ?? []
        let spO2: [SpO2Sample] = (try? await loadLegacyJSON(filename: "spo2.json")) ?? []
        let activity: [ActivitySample] = (try? await loadLegacyJSON(filename: "activity.json")) ?? []
        let hrv: [HRVSample] = (try? await loadLegacyJSON(filename: "hrv.json")) ?? []
        let temperature: [TemperatureSample] = (try? await loadLegacyJSON(filename: "temperature.json")) ?? []
        let sleep: [SleepRecord] = (try? await loadLegacyJSON(filename: "sleep.json")) ?? []
        
        // Save to Core Data
        if !heartRate.isEmpty || !stress.isEmpty || !spO2.isEmpty || !activity.isEmpty ||
           !hrv.isEmpty || !temperature.isEmpty || !sleep.isEmpty {
            
            try await saveAllData(
                heartRate: heartRate,
                stress: stress,
                spO2: spO2,
                activity: activity,
                hrv: hrv,
                temperature: temperature,
                sleep: sleep
            )
            
            // Backup legacy data before deletion
            try backupLegacyData()
            
            print("Migrated \(heartRate.count) heart rate, \(stress.count) stress, \(spO2.count) SpO2, \(activity.count) activity, \(hrv.count) HRV, \(temperature.count) temperature, \(sleep.count) sleep records")
        }
    }
    
    private func loadLegacyJSON<T: Codable>(filename: String) async throws -> T {
        let fileURL = legacyDataDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "StorageManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "File does not exist: \(filename)"])
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func backupLegacyData() throws {
        let backupDirectory = legacyDataDirectory.appendingPathComponent("backup_\(Date().timeIntervalSince1970)")
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        let files = try fileManager.contentsOfDirectory(at: legacyDataDirectory,
                                                        includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "json" {
            let destination = backupDirectory.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destination)
        }
    }
    
    // MARK: - Save Data
    
    func saveAllData(
        heartRate: [HeartRateSample],
        stress: [StressSample],
        spO2: [SpO2Sample],
        activity: [ActivitySample],
        hrv: [HRVSample],
        temperature: [TemperatureSample],
        sleep: [SleepRecord]
    ) async throws {
        
        try await saveHeartRate(heartRate)
        try await saveStress(stress)
        try await saveSpO2(spO2)
        try await saveActivity(activity)
        try await saveHRV(hrv)
        try await saveTemperature(temperature)
        try await saveSleep(sleep)
        
        print("All data saved to encrypted Core Data storage")
    }
    
    func saveHeartRate(_ samples: [HeartRateSample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            // Delete existing data
            try self.coreDataStack.batchDelete(entityType: HeartRateSampleEntity.self)
            
            // Create new entities
            for sample in samples {
                _ = HeartRateSampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) heart rate samples")
        }
    }
    
    func saveStress(_ samples: [StressSample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: StressSampleEntity.self)
            
            for sample in samples {
                _ = StressSampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) stress samples")
        }
    }
    
    func saveSpO2(_ samples: [SpO2Sample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: SpO2SampleEntity.self)
            
            for sample in samples {
                _ = SpO2SampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) SpO2 samples")
        }
    }
    
    func saveActivity(_ samples: [ActivitySample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: ActivitySampleEntity.self)
            
            for sample in samples {
                _ = ActivitySampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) activity samples")
        }
    }
    
    func saveHRV(_ samples: [HRVSample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: HRVSampleEntity.self)
            
            for sample in samples {
                _ = HRVSampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) HRV samples")
        }
    }
    
    func saveTemperature(_ samples: [TemperatureSample]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: TemperatureSampleEntity.self)
            
            for sample in samples {
                _ = TemperatureSampleEntity.create(from: sample, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(samples.count) temperature samples")
        }
    }
    
    func saveSleep(_ records: [SleepRecord]) async throws {
        let context = coreDataStack.newBackgroundContext()
        
        try await context.perform {
            try self.coreDataStack.batchDelete(entityType: SleepRecordEntity.self)
            
            for record in records {
                _ = SleepRecordEntity.create(from: record, context: context)
            }
            
            try self.coreDataStack.saveContext(context)
            print("Saved \(records.count) sleep records")
        }
    }
    
    // MARK: - Load Data
    
    func loadAllData() async throws -> (
        heartRate: [HeartRateSample],
        stress: [StressSample],
        spO2: [SpO2Sample],
        activity: [ActivitySample],
        hrv: [HRVSample],
        temperature: [TemperatureSample],
        sleep: [SleepRecord]
    ) {
        
        let heartRate = (try? await loadHeartRate()) ?? []
        let stress = (try? await loadStress()) ?? []
        let spO2 = (try? await loadSpO2()) ?? []
        let activity = (try? await loadActivity()) ?? []
        let hrv = (try? await loadHRV()) ?? []
        let temperature = (try? await loadTemperature()) ?? []
        let sleep = (try? await loadSleep()) ?? []
        
        print("Loaded data from encrypted Core Data storage")
        
        return (heartRate, stress, spO2, activity, hrv, temperature, sleep)
    }
    
    func loadHeartRate() async throws -> [HeartRateSample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = HeartRateSampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadStress() async throws -> [StressSample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = StressSampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadSpO2() async throws -> [SpO2Sample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = SpO2SampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadActivity() async throws -> [ActivitySample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = ActivitySampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadHRV() async throws -> [HRVSample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = HRVSampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadTemperature() async throws -> [TemperatureSample] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = TemperatureSampleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    func loadSleep() async throws -> [SleepRecord] {
        let context = coreDataStack.viewContext
        
        return try await context.perform {
            let fetchRequest = SleepRecordEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
            
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toModel() }
        }
    }
    
    // MARK: - Delete Data
    
    func deleteAllData() async throws {
        try coreDataStack.batchDelete(entityType: HeartRateSampleEntity.self)
        try coreDataStack.batchDelete(entityType: StressSampleEntity.self)
        try coreDataStack.batchDelete(entityType: SpO2SampleEntity.self)
        try coreDataStack.batchDelete(entityType: ActivitySampleEntity.self)
        try coreDataStack.batchDelete(entityType: HRVSampleEntity.self)
        try coreDataStack.batchDelete(entityType: TemperatureSampleEntity.self)
        try coreDataStack.batchDelete(entityType: SleepRecordEntity.self)
        
        print("Deleted all encrypted data")
    }
    
    func deleteFile(filename: String) async throws {
        // Map legacy filename to entity type
        switch filename {
        case "heartrate.json":
            try coreDataStack.batchDelete(entityType: HeartRateSampleEntity.self)
        case "stress.json":
            try coreDataStack.batchDelete(entityType: StressSampleEntity.self)
        case "spo2.json":
            try coreDataStack.batchDelete(entityType: SpO2SampleEntity.self)
        case "activity.json":
            try coreDataStack.batchDelete(entityType: ActivitySampleEntity.self)
        case "hrv.json":
            try coreDataStack.batchDelete(entityType: HRVSampleEntity.self)
        case "temperature.json":
            try coreDataStack.batchDelete(entityType: TemperatureSampleEntity.self)
        case "sleep.json":
            try coreDataStack.batchDelete(entityType: SleepRecordEntity.self)
        default:
            throw NSError(domain: "StorageManager", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Unknown file: \(filename)"])
        }
        
        print("Deleted data for: \(filename)")
    }
    
    // MARK: - Utility
    
    func getStorageSize() -> Int64 {
        guard let storeURL = coreDataStack.persistentContainer.persistentStoreDescriptions.first?.url else {
            return 0
        }
        
        do {
            let resourceValues = try storeURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            print("Error getting storage size: \(error)")
            return 0
        }
    }
    
    func getFileCount() -> Int {
        // Return count of entity types with data
        var count = 0
        let context = coreDataStack.viewContext
        
        let entityTypes: [NSManagedObject.Type] = [
            HeartRateSampleEntity.self,
            StressSampleEntity.self,
            SpO2SampleEntity.self,
            ActivitySampleEntity.self,
            HRVSampleEntity.self,
            TemperatureSampleEntity.self,
            SleepRecordEntity.self
        ]
        
        for entityType in entityTypes {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType))
            fetchRequest.fetchLimit = 1
            
            if let entityCount = try? context.count(for: fetchRequest), entityCount > 0 {
                count += 1
            }
        }
        
        return count
    }
    
    // MARK: - Export to JSON (for backup/compatibility)
    
    func exportToJSON() async throws -> [String: Data] {
        var exports: [String: Data] = [:]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let heartRate = try await loadHeartRate()
        let stress = try await loadStress()
        let spO2 = try await loadSpO2()
        let activity = try await loadActivity()
        let hrv = try await loadHRV()
        let temperature = try await loadTemperature()
        let sleep = try await loadSleep()
        
        exports["heartrate.json"] = try encoder.encode(heartRate)
        exports["stress.json"] = try encoder.encode(stress)
        exports["spo2.json"] = try encoder.encode(spO2)
        exports["activity.json"] = try encoder.encode(activity)
        exports["hrv.json"] = try encoder.encode(hrv)
        exports["temperature.json"] = try encoder.encode(temperature)
        exports["sleep.json"] = try encoder.encode(sleep)
        
        return exports
    }
}
