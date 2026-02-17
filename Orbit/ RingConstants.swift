//
//  RingConstants.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import AccessorySetupKit
import Foundation
import UIKit

enum RingConstants {
    // MARK: - UUID Constants

    // V2 (Yawell proprietary) service
    static let mainServiceUUID = "DE5BF728-D711-4E47-AF26-65E3012A5DC7"
    static let mainWriteCharacteristicUUID = "DE5BF72A-D711-4E47-AF26-65E3012A5DC7"
    static let mainNotifyCharacteristicUUID = "DE5BF729-D711-4E47-AF26-65E3012A5DC7"

    // V1 (Nordic UART) service - used for all standard commands
    static let ringServiceUUID = "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartRxCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartTxCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    static let deviceInfoServiceUUID = "0000180A-0000-1000-8000-00805F9B34FB"
    static let deviceHardwareUUID = "00002A27-0000-1000-8000-00805F9B34FB"
    static let deviceFirmwareUUID = "00002A26-0000-1000-8000-00805F9B34FB"

    // MARK: - Command Constants (matched exactly to Gadgetbridge YawellRingConstants)

    static let CMD_SET_DATE_TIME: UInt8 = 0x01
    static let CMD_BATTERY: UInt8 = 0x03
    static let CMD_PHONE_NAME: UInt8 = 0x04
    static let CMD_DISPLAY_PREF: UInt8 = 0x05 // FIX: was 0x62
    static let CMD_PREFERENCES: UInt8 = 0x0A // FIX: was 0x06
    static let CMD_POWER_OFF: UInt8 = 0x08 // correct
    // FIX: removed CMD_FACTORY_RESET = 0x09 (wrong); correct value is 0xff below
    static let CMD_SYNC_HEART_RATE: UInt8 = 0x15 // FIX: was 0x12
    static let CMD_AUTO_HR_PREF: UInt8 = 0x16 // FIX: was 0x23
    static let CMD_REALTIME_HEART_RATE: UInt8 = 0x1E // FIX: was 0x69
    static let CMD_GOALS: UInt8 = 0x21 // FIX: was 0x46
    static let CMD_AUTO_SPO2_PREF: UInt8 = 0x2C // FIX: was 0x35
    static let CMD_PACKET_SIZE: UInt8 = 0x2F // FIX: was 0x22
    static let CMD_AUTO_STRESS_PREF: UInt8 = 0x36 // FIX: was 0x52 (also fixed CMD_SYNC_STRESS collision)
    static let CMD_SYNC_STRESS: UInt8 = 0x37 // FIX: was 0x52 (SAME as CMD_AUTO_STRESS_PREF — broken)
    static let CMD_AUTO_HRV_PREF: UInt8 = 0x38 // FIX: was 0x36 (collided with CMD_AUTO_STRESS_PREF)
    static let CMD_SYNC_HRV: UInt8 = 0x39 // FIX: was 0x36 (same as CMD_AUTO_HRV_PREF — broken)
    static let CMD_AUTO_TEMP_PREF: UInt8 = 0x3A // FIX: was 0x60
    static let CMD_SYNC_ACTIVITY: UInt8 = 0x43 // FIX: was 0x10
    static let CMD_FIND_DEVICE: UInt8 = 0x50 // FIX: was 0x07
    static let CMD_MANUAL_HEART_RATE: UInt8 = 0x69 // FIX: was 0x11
    static let CMD_NOTIFICATION: UInt8 = 0x73 // FIX: was 0x64
    static let CMD_BIG_DATA_V2: UInt8 = 0xBC // FIX: was 0x24
    static let CMD_FACTORY_RESET: UInt8 = 0xFF // FIX: was 0x09

    // MARK: - Big Data Types (matched to Gadgetbridge)

    static let BIG_DATA_TYPE_TEMPERATURE: UInt8 = 0x25 // FIX: was 0x0E
    static let BIG_DATA_TYPE_SLEEP: UInt8 = 0x27 // FIX: was 0x0A
    static let BIG_DATA_TYPE_SPO2: UInt8 = 0x2A // FIX: was 0x06

    // MARK: - Sleep Stage Types (matched to Gadgetbridge)

    static let SLEEP_TYPE_LIGHT: UInt8 = 0x02 // FIX: Orbit had 0x01
    static let SLEEP_TYPE_DEEP: UInt8 = 0x03 // FIX: Orbit had 0x02
    static let SLEEP_TYPE_REM: UInt8 = 0x04 // FIX: Orbit had 0x03
    static let SLEEP_TYPE_AWAKE: UInt8 = 0x05 // FIX: Orbit had 0x00

    // MARK: - Notification Types (matched to Gadgetbridge)

    static let NOTIFICATION_NEW_HR_DATA: UInt8 = 0x01 // correct
    static let NOTIFICATION_NEW_SPO2_DATA: UInt8 = 0x03 // FIX: was 0x02
    static let NOTIFICATION_NEW_STEPS_DATA: UInt8 = 0x04 // FIX: was 0x03
    static let NOTIFICATION_BATTERY_LEVEL: UInt8 = 0x0C // FIX: was 0x04
    static let NOTIFICATION_LIVE_ACTIVITY: UInt8 = 0x12 // FIX: was 0x0A

    // MARK: - Preference Read/Write

    static let PREF_READ: UInt8 = 0x01 // FIX: was 0x00
    static let PREF_WRITE: UInt8 = 0x02 // FIX: was 0x01

    // MARK: - Device Capability Flags

    /// Used to gate features per supported ring model
    struct DeviceCapabilities: OptionSet {
        let rawValue: UInt32
        static let temperature = DeviceCapabilities(rawValue: 1 << 0)
        static let continuousTemp = DeviceCapabilities(rawValue: 1 << 1)
        static let display = DeviceCapabilities(rawValue: 1 << 2)
    }

    // MARK: - Known Device Models

    enum RingModel: String, CaseIterable {
        // Yawell-branded
        case yawellR05 = "Yawell R05"
        case yawellR10 = "Yawell R10"
        case yawellR11 = "Yawell R11"
        // Colmi-branded (same protocol)
        case colmiR02 = "Colmi R02"
        case colmiR03 = "Colmi R03"
        case colmiR06 = "Colmi R06"
        case colmiR07 = "Colmi R07"
        case colmiR09 = "Colmi R09"
        case colmiR10 = "Colmi R10"
        case colmiR12 = "Colmi R12"
        case unknown = "Unknown Ring"

        var capabilities: DeviceCapabilities {
            switch self {
            case .yawellR05, .yawellR10, .colmiR09:
                return [.temperature, .continuousTemp]
            case .yawellR11, .colmiR12:
                return [.display]
            default:
                return []
            }
        }

        var supportsTemperature: Bool {
            capabilities.contains(.temperature)
        }

        var supportsContinuousTemperature: Bool {
            capabilities.contains(.continuousTemp)
        }

        var hasDisplay: Bool {
            capabilities.contains(.display)
        }

        /// Detect model from BLE advertisement name
        static func from(advertisedName: String) -> RingModel {
            let name = advertisedName.uppercased()
            if name.matches("R05_[0-9A-F]{4}") { return .yawellR05 }
            if name.matches("R10_[0-9A-F]{4}") { return .yawellR10 }
            if name.matches("R11C?_[0-9A-F]{4}") { return .yawellR11 }
            if name.matches("R02_.*") { return .colmiR02 }
            if name.matches("R03_.*") { return .colmiR03 }
            if name.matches("R06_.*") { return .colmiR06 }
            if name.matches("COLMI R07_.*") { return .colmiR07 }
            if name.matches("R09_.*") { return .colmiR09 }
            if name.matches("^COLMI R10_.*") { return .colmiR10 }
            if name.matches("^COLMI R12_.*") { return .colmiR12 }
            return .unknown
        }
    }

    // MARK: - Stress Ranges (from Gadgetbridge)

    /// 1-29 = relaxed, 30-59 = normal, 60-79 = medium, 80-99 = high
    static let stressRanges: [Int] = [1, 30, 60, 80]

    static func stressLabel(for level: Int) -> String {
        if level < 30 { return "Relaxed" }
        if level < 60 { return "Normal" }
        if level < 80 { return "Medium" }
        return "High"
    }

    // MARK: - Heart Rate Measurement Intervals (minutes)

    static let heartRateMeasurementIntervals: [Int] = [0, 5, 10, 15, 30, 45, 60]

    // MARK: - Picker Configuration

    static let pickerDisplayItem: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(4660)

        return ASPickerDisplayItem(
            name: "COLMI Ring",
            productImage: UIImage(named: "colmi")!,
            descriptor: descriptor
        )
    }()
}

// MARK: - String regex helper

private extension String {
    func matches(_ pattern: String) -> Bool {
        (try? NSRegularExpression(pattern: pattern))
            .map { $0.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) != nil }
            ?? false
    }
}
