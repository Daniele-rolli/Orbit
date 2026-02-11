//
//  StorageManager.swift
//  Orbit
//
//  Manages encrypted storage of ring data
//

import Foundation

class StorageManager {
    
    private let fileManager = FileManager.default
    
    // Storage paths
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var dataDirectory: URL {
        documentsDirectory.appendingPathComponent("RingData", isDirectory: true)
    }
    
    init() {
        createDataDirectoryIfNeeded()
    }
    
    private func createDataDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: dataDirectory.path) {
            try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
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
        
        print("All data saved to encrypted storage")
    }
    
    func saveHeartRate(_ samples: [HeartRateSample]) async throws {
        try await save(samples, filename: "heartrate.json")
    }
    
    func saveStress(_ samples: [StressSample]) async throws {
        try await save(samples, filename: "stress.json")
    }
    
    func saveSpO2(_ samples: [SpO2Sample]) async throws {
        try await save(samples, filename: "spo2.json")
    }
    
    func saveActivity(_ samples: [ActivitySample]) async throws {
        try await save(samples, filename: "activity.json")
    }
    
    func saveHRV(_ samples: [HRVSample]) async throws {
        try await save(samples, filename: "hrv.json")
    }
    
    func saveTemperature(_ samples: [TemperatureSample]) async throws {
        try await save(samples, filename: "temperature.json")
    }
    
    func saveSleep(_ records: [SleepRecord]) async throws {
        try await save(records, filename: "sleep.json")
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
        
        let heartRate: [HeartRateSample] = (try? await load(filename: "heartrate.json")) ?? []
        let stress: [StressSample] = (try? await load(filename: "stress.json")) ?? []
        let spO2: [SpO2Sample] = (try? await load(filename: "spo2.json")) ?? []
        let activity: [ActivitySample] = (try? await load(filename: "activity.json")) ?? []
        let hrv: [HRVSample] = (try? await load(filename: "hrv.json")) ?? []
        let temperature: [TemperatureSample] = (try? await load(filename: "temperature.json")) ?? []
        let sleep: [SleepRecord] = (try? await load(filename: "sleep.json")) ?? []
        
        print("Loaded data from encrypted storage")
        
        return (heartRate, stress, spO2, activity, hrv, temperature, sleep)
    }
    
    // MARK: - Generic Save/Load with Encryption
    
    private func save<T: Codable>(_ data: T, filename: String) async throws {
        let fileURL = dataDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        
        // Create encrypted file with complete protection
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.complete
        ]
        
        // Ensure parent directory exists
        createDataDirectoryIfNeeded()
        
        // Write with encryption
        let success = fileManager.createFile(
            atPath: fileURL.path,
            contents: jsonData,
            attributes: attributes
        )
        
        if !success {
            throw NSError(
                domain: "StorageManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create encrypted file"]
            )
        }
        
        print("Saved encrypted file: \(filename)")
    }
    
    private func load<T: Codable>(filename: String) async throws -> T {
        let fileURL = dataDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw NSError(
                domain: "StorageManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "File does not exist: \(filename)"]
            )
        }
        
        let data = try Data(contentsOf: fileURL)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(T.self, from: data)
        
        print("Loaded encrypted file: \(filename)")
        
        return decoded
    }
    
    // MARK: - Delete Data
    
    func deleteAllData() async throws {
        let files = ["heartrate.json", "stress.json", "spo2.json", "activity.json",
                     "hrv.json", "temperature.json", "sleep.json"]
        
        for filename in files {
            let fileURL = dataDirectory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
        
        print("Deleted all encrypted files")
    }
    
    func deleteFile(filename: String) async throws {
        let fileURL = dataDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            print("Deleted encrypted file: \(filename)")
        }
    }
    
    // MARK: - Utility
    
    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: dataDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    func getFileCount() -> Int {
        (try? fileManager.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil))?.count ?? 0
    }
}
