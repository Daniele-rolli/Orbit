//
//  CoreDataEntityExtensions.swift
//  Orbit
//
//  Created by Daniele Rolli on 2/11/26.
//

import Foundation
import CoreData

// MARK: - HeartRateSampleEntity

extension HeartRateSampleEntity {
    
    func toModel() -> HeartRateSample {
        return HeartRateSample(
            timestamp: timestamp ?? Date(),
            heartRate: Int(heartRate)
        )
    }
    
    func update(from sample: HeartRateSample) {
        self.timestamp = sample.timestamp
        self.heartRate = Int32(sample.heartRate)
    }
    
    static func create(from sample: HeartRateSample, context: NSManagedObjectContext) -> HeartRateSampleEntity {
        let entity = HeartRateSampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - StressSampleEntity

extension StressSampleEntity {
    
    func toModel() -> StressSample {
        return StressSample(
            timestamp: timestamp ?? Date(),
            stressLevel: Int(stressLevel)
        )
    }
    
    func update(from sample: StressSample) {
        self.timestamp = sample.timestamp
        self.stressLevel = Int32(sample.stressLevel)
    }
    
    static func create(from sample: StressSample, context: NSManagedObjectContext) -> StressSampleEntity {
        let entity = StressSampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - SpO2SampleEntity

extension SpO2SampleEntity {
    
    func toModel() -> SpO2Sample {
        return SpO2Sample(
            timestamp: timestamp ?? Date(),
            spO2: Int(spO2)
        )
    }
    
    func update(from sample: SpO2Sample) {
        self.timestamp = sample.timestamp
        self.spO2 = Int32(sample.spO2)
    }
    
    static func create(from sample: SpO2Sample, context: NSManagedObjectContext) -> SpO2SampleEntity {
        let entity = SpO2SampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - ActivitySampleEntity

extension ActivitySampleEntity {
    
    func toModel() -> ActivitySample {
        return ActivitySample(
            timestamp: timestamp ?? Date(),
            steps: Int(steps),
            distance: Int(distance),
            calories: Int(calories)
        )
    }
    
    func update(from sample: ActivitySample) {
        self.timestamp = sample.timestamp
        self.steps = Int32(sample.steps)
        self.distance = Int32(sample.distance)
        self.calories = Int32(sample.calories)
    }
    
    static func create(from sample: ActivitySample, context: NSManagedObjectContext) -> ActivitySampleEntity {
        let entity = ActivitySampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - HRVSampleEntity

extension HRVSampleEntity {
    
    func toModel() -> HRVSample {
        return HRVSample(
            timestamp: timestamp ?? Date(),
            hrvValue: Int(hrvValue)
        )
    }
    
    func update(from sample: HRVSample) {
        self.timestamp = sample.timestamp
        self.hrvValue = Int32(sample.hrvValue)
    }
    
    static func create(from sample: HRVSample, context: NSManagedObjectContext) -> HRVSampleEntity {
        let entity = HRVSampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - TemperatureSampleEntity

extension TemperatureSampleEntity {
    
    func toModel() -> TemperatureSample {
        return TemperatureSample(
            timestamp: timestamp ?? Date(),
            temperature: temperature
        )
    }
    
    func update(from sample: TemperatureSample) {
        self.timestamp = sample.timestamp
        self.temperature = sample.temperature
    }
    
    static func create(from sample: TemperatureSample, context: NSManagedObjectContext) -> TemperatureSampleEntity {
        let entity = TemperatureSampleEntity(context: context)
        entity.update(from: sample)
        return entity
    }
}

// MARK: - SleepRecordEntity

extension SleepRecordEntity {
    
    func toModel() -> SleepRecord {
        let sleepTypeValue = SleepRecord.SleepType(rawValue: UInt8(sleepType)) ?? .awake
        return SleepRecord(
            startTime: startTime ?? Date(),
            endTime: endTime ?? Date(),
            sleepType: sleepTypeValue
        )
    }
    
    func update(from record: SleepRecord) {
        self.startTime = record.startTime
        self.endTime = record.endTime
        self.sleepType = Int16(record.sleepType.rawValue)
    }
    
    static func create(from record: SleepRecord, context: NSManagedObjectContext) -> SleepRecordEntity {
        let entity = SleepRecordEntity(context: context)
        entity.update(from: record)
        return entity
    }
}
