//
//  RealTime.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

enum RealTimeReading: UInt8 {
    case heartRate = 0x01
    case bloodOxygen = 0x02
    case stress = 0x03
    case temperature = 0x04
}
