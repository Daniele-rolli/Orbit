//
//  Samples.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

struct HeartRateSample: Codable, Equatable {
    let timestamp: Date
    let heartRate: Int
}

struct StressSample: Codable, Equatable {
    let timestamp: Date
    let stressLevel: Int
}

struct SpO2Sample: Codable, Equatable {
    let timestamp: Date
    let spO2: Int
}

struct ActivitySample: Codable, Equatable {
    let timestamp: Date
    let steps: Int
    let distance: Int // in meters
    let calories: Int
}

struct HRVSample: Codable, Equatable {
    let timestamp: Date
    let hrvValue: Int
}

struct TemperatureSample: Codable, Equatable {
    let timestamp: Date
    let temperature: Double // in Celsius
}
