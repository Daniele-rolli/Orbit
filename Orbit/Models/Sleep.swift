//
//  Sleep.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

struct SleepRecord: Codable {
    let startTime: Date
    let endTime: Date
    let sleepType: SleepType
    
    enum SleepType: UInt8, Codable {
        case awake = 0x00
        case light = 0x01
        case deep = 0x02
        case rem = 0x03
    }
}
