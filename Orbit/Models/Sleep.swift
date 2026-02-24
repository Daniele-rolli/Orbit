//
//  Sleep.swift
//  Orbit
//

import Foundation
import SwiftUI

struct SleepRecord: Codable, Equatable {
    let startTime: Date
    let endTime: Date
    let sleepType: SleepType

    // FIX: raw values corrected to match Gadgetbridge / ring protocol constants:
    // SLEEP_TYPE_LIGHT  = 0x02
    // SLEEP_TYPE_DEEP   = 0x03
    // SLEEP_TYPE_REM    = 0x04
    // SLEEP_TYPE_AWAKE  = 0x05
    // (was 0x00-0x03 which is wrong and maps stages to the wrong bytes)
    enum SleepType: UInt8, Codable, CaseIterable {
        case light = 0x02
        case deep = 0x03
        case rem = 0x04
        case awake = 0x05

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .deep: return "Deep"
            case .rem: return "REM"
            case .awake: return "Awake"
            }
        }

        var chartColor: Color {
            switch self {
            case .light: return .blue
            case .deep: return .purple
            case .rem: return .green
            case .awake: return .orange
            }
        }
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}
