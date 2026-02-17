//
//  StorageManager.swift
//  Orbit
//
//  Manages encrypted storage of ring data using Core Data
//

import CoreData
import Foundation

class StorageManager {
    private let coreDataStack = CoreDataStack.shared
    private let fileManager = FileManager.default

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
        guard fileManager.fileExists(atPath: legacyDataDirectory.path) else { return }

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
        let heartRate: [HeartRateSample] = (try? await loadLegacyJSON(filename: "heartrate.json")) ?? []
        let stress: [StressSample] = (try? await loadLegacyJSON(filename: "stress.json")) ?? []
        let spO2: [SpO2Sample] = (try? await loadLegacyJSON(filename: "spo2.json")) ?? []
        let activity: [ActivitySample] = (try? await loadLegacyJSON(filename: "activity.json")) ?? []
        let hrv: [HRVSample] = (try? await loadLegacyJSON(filename: "hrv.json")) ?? []
        let temperature: [TemperatureSample] = (try? await loadLegacyJSON(filename: "temperature.json")) ?? []
        let sleep: [SleepRecord] = (try? await loadLegacyJSON(filename: "sleep.json")) ?? []

        guard !heartRate.isEmpty || !stress.isEmpty || !spO2.isEmpty || !activity.isEmpty ||
            !hrv.isEmpty || !temperature.isEmpty || !sleep.isEmpty else { return }

        try await saveAllData(
            heartRate: heartRate,
            stress: stress,
            spO2: spO2,
            activity: activity,
            hrv: hrv,
            temperature: temperature,
            sleep: sleep
        )

        try backupLegacyData()

        print("Migrated \(heartRate.count) HR, \(stress.count) stress, \(spO2.count) SpO2, " +
            "\(activity.count) activity, \(hrv.count) HRV, \(temperature.count) temperature, " +
            "\(sleep.count) sleep records")
    }

    private func loadLegacyJSON<T: Codable>(filename: String) async throws -> T {
        let fileURL = legacyDataDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func backupLegacyData() throws {
        let backupDir = legacyDataDirectory
            .appendingPathComponent("backup_\(Int(Date().timeIntervalSince1970))")
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let files = try fileManager.contentsOfDirectory(at: legacyDataDirectory,
                                                        includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "json" {
            try fileManager.copyItem(at: file, to: backupDir.appendingPathComponent(file.lastPathComponent))
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
        try await performSave(entityName: "HeartRateSampleEntity") { context in
            for sample in samples {
                _ = HeartRateSampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) heart rate samples")
    }

    func saveStress(_ samples: [StressSample]) async throws {
        try await performSave(entityName: "StressSampleEntity") { context in
            for sample in samples {
                _ = StressSampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) stress samples")
    }

    func saveSpO2(_ samples: [SpO2Sample]) async throws {
        try await performSave(entityName: "SpO2SampleEntity") { context in
            for sample in samples {
                _ = SpO2SampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) SpO2 samples")
    }

    func saveActivity(_ samples: [ActivitySample]) async throws {
        try await performSave(entityName: "ActivitySampleEntity") { context in
            for sample in samples {
                _ = ActivitySampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) activity samples")
    }

    func saveHRV(_ samples: [HRVSample]) async throws {
        try await performSave(entityName: "HRVSampleEntity") { context in
            for sample in samples {
                _ = HRVSampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) HRV samples")
    }

    func saveTemperature(_ samples: [TemperatureSample]) async throws {
        try await performSave(entityName: "TemperatureSampleEntity") { context in
            for sample in samples {
                _ = TemperatureSampleEntity.create(from: sample, context: context)
            }
        }
        print("Saved \(samples.count) temperature samples")
    }

    func saveSleep(_ records: [SleepRecord]) async throws {
        try await performSave(entityName: "SleepRecordEntity") { context in
            for record in records {
                _ = SleepRecordEntity.create(from: record, context: context)
            }
        }
        print("Saved \(records.count) sleep records")
    }

    // MARK: - Core Save Helper

    private func performSave(
        entityName: String,
        insertions: @escaping (NSManagedObjectContext) throws -> Void
    ) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeObjectIDs

            let result = try context.execute(batchDelete) as? NSBatchDeleteResult

            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [self.coreDataStack.viewContext]
                )
            }

            // Insert the new records
            try insertions(context)

            if context.hasChanges {
                try context.save()
            }
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
        try await loadEntities(
            fetchRequest: HeartRateSampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadStress() async throws -> [StressSample] {
        try await loadEntities(
            fetchRequest: StressSampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadSpO2() async throws -> [SpO2Sample] {
        try await loadEntities(
            fetchRequest: SpO2SampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadActivity() async throws -> [ActivitySample] {
        try await loadEntities(
            fetchRequest: ActivitySampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadHRV() async throws -> [HRVSample] {
        try await loadEntities(
            fetchRequest: HRVSampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadTemperature() async throws -> [TemperatureSample] {
        try await loadEntities(
            fetchRequest: TemperatureSampleEntity.fetchRequest(),
            sortKey: "timestamp"
        ) { $0.toModel() }
    }

    func loadSleep() async throws -> [SleepRecord] {
        try await loadEntities(
            fetchRequest: SleepRecordEntity.fetchRequest(),
            sortKey: "startTime"
        ) { $0.toModel() }
    }

    // MARK: - Generic Load Helper
    private func loadEntities<Entity: NSManagedObject, Model>(
        fetchRequest: NSFetchRequest<Entity>,
        sortKey: String,
        transform: @escaping (Entity) -> Model
    ) async throws -> [Model] {
        let context = coreDataStack.viewContext
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(fetchRequest)
            return entities.map(transform)
        }
    }

    // MARK: - Delete Data

    func deleteAllData() async throws {
        let entityNames = [
            "HeartRateSampleEntity",
            "StressSampleEntity",
            "SpO2SampleEntity",
            "ActivitySampleEntity",
            "HRVSampleEntity",
            "TemperatureSampleEntity",
            "SleepRecordEntity",
        ]

        let context = coreDataStack.newBackgroundContext()
        try await context.perform {
            for name in entityNames {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let req = NSBatchDeleteRequest(fetchRequest: fr)
                req.resultType = .resultTypeObjectIDs
                let result = try context.execute(req) as? NSBatchDeleteResult
                if let ids = result?.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                        into: [self.coreDataStack.viewContext]
                    )
                }
            }
        }

        print("Deleted all encrypted data")
    }

    // MARK: - Utility

    func getStorageSize() -> Int64 {
        guard let storeURL = coreDataStack.persistentContainer
            .persistentStoreDescriptions.first?.url else { return 0 }

        do {
            let values = try storeURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            print("Error getting storage size: \(error)")
            return 0
        }
    }

    func getFileCount() -> Int {
        let context = coreDataStack.viewContext
        let entityNames = [
            "HeartRateSampleEntity", "StressSampleEntity", "SpO2SampleEntity",
            "ActivitySampleEntity", "HRVSampleEntity", "TemperatureSampleEntity",
            "SleepRecordEntity",
        ]

        return entityNames.filter { name in
            let fr = NSFetchRequest<NSManagedObject>(entityName: name)
            fr.fetchLimit = 1
            return (try? context.count(for: fr)).map { $0 > 0 } ?? false
        }.count
    }

    // MARK: - Export to JSON (for backup/sharing)

    func exportToJSON() async throws -> [String: Data] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        async let hr = loadHeartRate()
        async let s = loadStress()
        async let spo2 = loadSpO2()
        async let act = loadActivity()
        async let hrv = loadHRV()
        async let temp = loadTemperature()
        async let slp = loadSleep()

        return try await [
            "heartrate.json": encoder.encode(hr),
            "stress.json": encoder.encode(s),
            "spo2.json": encoder.encode(spo2),
            "activity.json": encoder.encode(act),
            "hrv.json": encoder.encode(hrv),
            "temperature.json": encoder.encode(temp),
            "sleep.json": encoder.encode(slp),
        ]
    }

    // MARK: - Error Types

    enum StorageError: LocalizedError {
        case fileNotFound(String)

        var errorDescription: String? {
            switch self {
            case let .fileNotFound(name): return "File does not exist: \(name)"
            }
        }
    }
}
