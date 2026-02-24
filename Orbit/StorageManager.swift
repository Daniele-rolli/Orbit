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

        try await mergeAllData(
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

    // MARK: - Merge (Upsert) Data
    //
    // These methods INSERT new records and UPDATE existing ones matched by timestamp.
    // They never wipe existing data, so records survive across launches and partial
    // ring syncs can never clobber previously-saved history.

    func mergeAllData(
        heartRate: [HeartRateSample],
        stress: [StressSample],
        spO2: [SpO2Sample],
        activity: [ActivitySample],
        hrv: [HRVSample],
        temperature: [TemperatureSample],
        sleep: [SleepRecord]
    ) async throws {
        try await mergeHeartRate(heartRate)
        try await mergeStress(stress)
        try await mergeSpO2(spO2)
        try await mergeActivity(activity)
        try await mergeHRV(hrv)
        try await mergeTemperature(temperature)
        try await mergeSleep(sleep)
        print("All data merged into encrypted Core Data storage")
    }

    /// Backward-compatible alias used by RingSessionManager.saveDataToEncryptedStorage()
    func saveAllData(
        heartRate: [HeartRateSample],
        stress: [StressSample],
        spO2: [SpO2Sample],
        activity: [ActivitySample],
        hrv: [HRVSample],
        temperature: [TemperatureSample],
        sleep: [SleepRecord]
    ) async throws {
        try await mergeAllData(
            heartRate: heartRate,
            stress: stress,
            spO2: spO2,
            activity: activity,
            hrv: hrv,
            temperature: temperature,
            sleep: sleep
        )
    }

    func mergeHeartRate(_ samples: [HeartRateSample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "HeartRateSampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! HeartRateSampleEntity).update(from: sample) },
            creator: { context, sample in _ = HeartRateSampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) heart rate samples")
    }

    func mergeStress(_ samples: [StressSample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "StressSampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! StressSampleEntity).update(from: sample) },
            creator: { context, sample in _ = StressSampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) stress samples")
    }

    func mergeSpO2(_ samples: [SpO2Sample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "SpO2SampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! SpO2SampleEntity).update(from: sample) },
            creator: { context, sample in _ = SpO2SampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) SpO2 samples")
    }

    func mergeActivity(_ samples: [ActivitySample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "ActivitySampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! ActivitySampleEntity).update(from: sample) },
            creator: { context, sample in _ = ActivitySampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) activity samples")
    }

    func mergeHRV(_ samples: [HRVSample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "HRVSampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! HRVSampleEntity).update(from: sample) },
            creator: { context, sample in _ = HRVSampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) HRV samples")
    }

    func mergeTemperature(_ samples: [TemperatureSample]) async throws {
        guard !samples.isEmpty else { return }
        try await performUpsert(
            entityName: "TemperatureSampleEntity",
            timestampKey: "timestamp",
            samples: samples,
            timestampAccessor: { $0.timestamp },
            updater: { entity, sample in (entity as! TemperatureSampleEntity).update(from: sample) },
            creator: { context, sample in _ = TemperatureSampleEntity.create(from: sample, context: context) }
        )
        print("Merged \(samples.count) temperature samples")
    }

    func mergeSleep(_ records: [SleepRecord]) async throws {
        guard !records.isEmpty else { return }
        // Sleep records are keyed by startTime
        try await performUpsert(
            entityName: "SleepRecordEntity",
            timestampKey: "startTime",
            samples: records,
            timestampAccessor: { $0.startTime },
            updater: { entity, record in (entity as! SleepRecordEntity).update(from: record) },
            creator: { context, record in _ = SleepRecordEntity.create(from: record, context: context) }
        )
        print("Merged \(records.count) sleep records")
    }

    // MARK: - Generic Upsert Helper
    //
    // Fetches entities whose timestamp falls in the incoming batch's date range,
    // updates any that match by exact timestamp, inserts the rest as new rows.
    // Existing records outside the incoming date range are never touched.

    private func performUpsert<Sample>(
        entityName: String,
        timestampKey: String,
        samples: [Sample],
        timestampAccessor: @escaping (Sample) -> Date,
        updater: @escaping (NSManagedObject, Sample) -> Void,
        creator: @escaping (NSManagedObjectContext, Sample) -> Void
    ) async throws {
        guard !samples.isEmpty else { return }

        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let timestamps = samples.map { timestampAccessor($0) }
            let minDate = timestamps.min()!
            let maxDate = timestamps.max()!

            // Fetch only the rows that overlap with the incoming data's window.
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(
                format: "%K >= %@ AND %K <= %@",
                timestampKey, minDate as NSDate,
                timestampKey, maxDate as NSDate
            )

            let existing = try context.fetch(fetchRequest)

            // Build an O(1) lookup by timestamp.
            var existingByTimestamp: [Date: NSManagedObject] = [:]
            for entity in existing {
                if let date = entity.value(forKey: timestampKey) as? Date {
                    existingByTimestamp[date] = entity
                }
            }

            // Upsert each incoming sample.
            for sample in samples {
                let ts = timestampAccessor(sample)
                if let existingEntity = existingByTimestamp[ts] {
                    updater(existingEntity, sample)
                } else {
                    creator(context, sample)
                }
            }

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
