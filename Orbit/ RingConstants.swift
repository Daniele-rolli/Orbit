//
//  RingConstants.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation
import UIKit
import AccessorySetupKit

enum RingConstants {
    
    // MARK: - UUID Constants
    static let mainServiceUUID = "DE5BF728-D711-4E47-AF26-65E3012A5DC7"
    static let mainWriteCharacteristicUUID = "DE5BF72A-D711-4E47-AF26-65E3012A5DC7"
    static let mainNotifyCharacteristicUUID = "DE5BF729-D711-4E47-AF26-65E3012A5DC7"
    
    static let ringServiceUUID = "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartRxCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartTxCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    static let deviceInfoServiceUUID = "0000180A-0000-1000-8000-00805F9B34FB"
    static let deviceHardwareUUID = "00002A27-0000-1000-8000-00805F9B34FB"
    static let deviceFirmwareUUID = "00002A26-0000-1000-8000-00805F9B34FB"
    
    // MARK: - Command Constants
    
    // Basic commands
    static let CMD_SET_DATE_TIME: UInt8 = 0x01
    static let CMD_BATTERY: UInt8 = 0x03
    static let CMD_PHONE_NAME: UInt8 = 0x04
    static let CMD_PREFERENCES: UInt8 = 0x06
    static let CMD_FIND_DEVICE: UInt8 = 0x07
    static let CMD_POWER_OFF: UInt8 = 0x08
    static let CMD_FACTORY_RESET: UInt8 = 0x09
    
    // Data sync commands
    static let CMD_SYNC_ACTIVITY: UInt8 = 0x10
    static let CMD_MANUAL_HEART_RATE: UInt8 = 0x11
    static let CMD_SYNC_HEART_RATE: UInt8 = 0x12
    static let CMD_PACKET_SIZE: UInt8 = 0x22
    static let CMD_AUTO_HR_PREF: UInt8 = 0x23
    static let CMD_BIG_DATA_V2: UInt8 = 0x24
    static let CMD_AUTO_SPO2_PREF: UInt8 = 0x35
    static let CMD_AUTO_HRV_PREF: UInt8 = 0x36
    static let CMD_GOALS: UInt8 = 0x46
    static let CMD_AUTO_STRESS_PREF: UInt8 = 0x52
    static let CMD_SYNC_STRESS: UInt8 = 0x52
    static let CMD_SYNC_HRV: UInt8 = 0x36
    static let CMD_AUTO_TEMP_PREF: UInt8 = 0x60
    static let CMD_DISPLAY_PREF: UInt8 = 0x62
    static let CMD_NOTIFICATION: UInt8 = 0x64
    static let CMD_REALTIME_HEART_RATE: UInt8 = 0x69
    
    // Big data types
    static let BIG_DATA_TYPE_SPO2: UInt8 = 0x06
    static let BIG_DATA_TYPE_SLEEP: UInt8 = 0x0A
    static let BIG_DATA_TYPE_TEMPERATURE: UInt8 = 0x0E
    
    // Notification types
    static let NOTIFICATION_NEW_HR_DATA: UInt8 = 0x01
    static let NOTIFICATION_NEW_SPO2_DATA: UInt8 = 0x02
    static let NOTIFICATION_NEW_STEPS_DATA: UInt8 = 0x03
    static let NOTIFICATION_BATTERY_LEVEL: UInt8 = 0x04
    static let NOTIFICATION_LIVE_ACTIVITY: UInt8 = 0x0A
    
    // Preference read/write
    static let PREF_READ: UInt8 = 0x00
    static let PREF_WRITE: UInt8 = 0x01
    
    // MARK: - Picker Configuration
    static let pickerDisplayItem: ASPickerDisplayItem = {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(4660)
        
        return ASPickerDisplayItem(
            name: "COLMI R02 Ring",
            productImage: UIImage(named: "colmi")!,
            descriptor: descriptor
        )
    }()
}
