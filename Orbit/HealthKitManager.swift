//
//  HealthKitManager.swift
//  Orbit
//
//  Manages HealthKit integration and data synchronization
//

import Foundation
import HealthKit

class HealthKitManager {
    
    private let healthStore = HKHealthStore()
    
    // Data types we want to write
    private let typesToWrite: Set<HKSampleType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    // Data types we want to read (optional - for comparing/deduplication)
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    
    // MARK: - Authorization
        
        func getAuthStatus() async throws -> HKAuthorizationRequestStatus {
            return try await healthStore.statusForAuthorizationRequest(toShare: typesToWrite, read: typesToRead)
        }

            @MainActor
            func requestAuthorization() async throws {
                guard HKHealthStore.isHealthDataAvailable() else {
                    throw NSError(domain: "HealthKitManager", code: -1)
                }

                try await healthStore.requestAuthorization(
                    toShare: typesToWrite,
                    read: typesToRead
                )
            }

        func canWriteData(for identifier: HKQuantityTypeIdentifier) -> Bool {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return false }
            let status = healthStore.authorizationStatus(for: type)
            return status == .sharingAuthorized
        }
    
    func isAuthorized() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        // Check authorization status for key types
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        return status == .sharingAuthorized
    }
    
    // MARK: - Sync All Data
    
    func syncAllData(
        heartRate: [HeartRateSample],
        activity: [ActivitySample],
        sleep: [SleepRecord]
    ) async throws {
        
        print("Starting HealthKit sync...")
        
        try await syncHeartRate(heartRate)
        try await syncActivity(activity)
        try await syncSleep(sleep)
        
        print("HealthKit sync completed")
    }
    
    // MARK: - Heart Rate
    
    func syncHeartRate(_ samples: [HeartRateSample]) async throws {
        guard !samples.isEmpty else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        
        let hkSamples = samples.map { sample in
            let quantity = HKQuantity(unit: heartRateUnit, doubleValue: Double(sample.heartRate))
            
            return HKQuantitySample(
                type: heartRateType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp,
                metadata: [
                    HKMetadataKeyHeartRateMotionContext: HKHeartRateMotionContext.sedentary.rawValue,
                    "Source": "COLMI R02 Ring"
                ]
            )
        }
        
        try await healthStore.save(hkSamples)
        print("Synced \(hkSamples.count) heart rate samples to HealthKit")
    }
    
    // MARK: - Activity
    
    func syncActivity(_ samples: [ActivitySample]) async throws {
        guard !samples.isEmpty else { return }
        
        var allSamples: [HKSample] = []
        
        // Steps
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(sample.steps))
            
            return HKQuantitySample(
                type: stepType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp.addingTimeInterval(60), // 1 minute duration
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        allSamples.append(contentsOf: stepSamples)
        
        // Distance
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let distanceSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .meter(), doubleValue: Double(sample.distance))
            
            return HKQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp.addingTimeInterval(60),
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        allSamples.append(contentsOf: distanceSamples)
        
        // Calories
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let calorieSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(sample.calories))
            
            return HKQuantitySample(
                type: calorieType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp.addingTimeInterval(60),
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        allSamples.append(contentsOf: calorieSamples)
        
        try await healthStore.save(allSamples)
        print("Synced \(samples.count) activity samples to HealthKit")
    }
    
    // MARK: - SpO2
    
    func syncSpO2(_ samples: [SpO2Sample]) async throws {
        guard !samples.isEmpty else { return }
        
        let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let hkSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .percent(), doubleValue: Double(sample.spO2) / 100.0)
            
            return HKQuantitySample(
                type: spo2Type,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp,
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        
        try await healthStore.save(hkSamples)
        print("Synced \(hkSamples.count) SpO2 samples to HealthKit")
    }
    
    // MARK: - HRV
    
    func syncHRV(_ samples: [HRVSample]) async throws {
        guard !samples.isEmpty else { return }
        
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let hkSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .secondUnit(with: .milli), doubleValue: Double(sample.hrvValue))
            
            return HKQuantitySample(
                type: hrvType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp,
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        
        try await healthStore.save(hkSamples)
        print("Synced \(hkSamples.count) HRV samples to HealthKit")
    }
    
    // MARK: - Temperature
    
    func syncTemperature(_ samples: [TemperatureSample]) async throws {
        guard !samples.isEmpty else { return }
        
        let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        
        let hkSamples = samples.map { sample in
            let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: sample.temperature)
            
            return HKQuantitySample(
                type: tempType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp,
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        
        try await healthStore.save(hkSamples)
        print("Synced \(hkSamples.count) temperature samples to HealthKit")
    }
    
    // MARK: - Sleep
    
    func syncSleep(_ records: [SleepRecord]) async throws {
        guard !records.isEmpty else { return }
        
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let hkSamples = records.compactMap { record -> HKCategorySample? in
            let value: HKCategoryValueSleepAnalysis
            
            switch record.sleepType {
            case .awake:
                value = .awake
            case .light:
                value = .asleepCore // Light sleep maps to core sleep in HealthKit
            case .deep:
                value = .asleepDeep
            case .rem:
                value = .asleepREM
            }
            
            return HKCategorySample(
                type: sleepType,
                value: value.rawValue,
                start: record.startTime,
                end: record.endTime,
                metadata: ["Source": "COLMI R02 Ring"]
            )
        }
        
        try await healthStore.save(hkSamples)
        print("Synced \(hkSamples.count) sleep records to HealthKit")
    }
    
    // MARK: - Query Existing Data (for deduplication)
    
    func queryHeartRate(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Delete Data
    
    func deleteRingData(from startDate: Date, to endDate: Date) async throws {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        for sampleType in typesToWrite {
            let objectsToDelete = try await queryObjects(ofType: sampleType, predicate: predicate)
            
            if !objectsToDelete.isEmpty {
                try await healthStore.delete(objectsToDelete)
                print("Deleted \(objectsToDelete.count) samples of type \(sampleType)")
            }
        }
    }
    
    private func queryObjects(ofType sampleType: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
}
