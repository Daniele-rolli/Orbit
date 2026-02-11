//
//  Displat.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

struct DisplaySettings {
    var enabled: Bool
    var wearLocation: WearLocation
    var brightness: Int // 0-4
    var allDay: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    
    enum WearLocation: UInt8 {
        case left = 0x01
        case right = 0x02
    }
}
