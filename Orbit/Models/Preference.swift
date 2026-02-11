//
//  Preference.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

struct UserPreferences {
    var gender: Gender
    var age: Int
    var heightCm: Int
    var weightKg: Int
    var measurementSystem: MeasurementSystem
    var timeFormat: TimeFormat
    var systolicBP: Int
    var diastolicBP: Int
    var hrWarningThreshold: Int
    
    enum Gender: UInt8 {
        case male = 0x00
        case female = 0x01
        case other = 0x02
    }
    
    enum MeasurementSystem: UInt8 {
        case metric = 0x00
        case imperial = 0x01
    }
    
    enum TimeFormat: UInt8 {
        case twentyFourHour = 0x00
        case twelveHour = 0x01
    }
}
