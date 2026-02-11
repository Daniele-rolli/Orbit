//
//  SyncManager.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation
import CoreBluetooth

class SyncManager {
    
    weak var sessionManager: RingSessionManager?
    
    var syncingDay: Date?
    var daysAgo: Int = 0
    var packetsTotalNr: Int = 0
    var currentHRPacketNr: Int = 0
    
    // Big data buffer
    var bigDataPacketSize: Int = 0
    var bigDataPacket: Data?
    
    // Packet handlers
    var packetHandlers: PacketHandlers!
    
    init(sessionManager: RingSessionManager) {
        self.sessionManager = sessionManager
        self.packetHandlers = PacketHandlers(syncManager: self)
    }
    
    private func sendCommand(_ command: UInt8, subData: [UInt8] = []) {
        sessionManager?.bluetoothManager?.sendCommand(command, subData: subData)
    }
    
    // MARK: - Main Sync Entry Point
    
    func fetchAllHistoricalData() {
        daysAgo = 0
        fetchHistoryActivity()
    }
    
    // MARK: - Activity
    
    func fetchHistoryActivity() {
        print("Fetching activity data for \(daysAgo) days ago")
        
        let calendar = Calendar.current
        syncingDay = calendar.date(byAdding: .day, value: -daysAgo, to: Date())
        
        let subData: [UInt8] = [
            UInt8(daysAgo),
            0x0f,
            0x00,
            0x5f,
            0x01
        ]
        
        sendCommand(RingConstants.CMD_SYNC_ACTIVITY, subData: subData)
    }
    
    // MARK: - Heart Rate
    
    func fetchHistoryHeartRate(daysAgo: Int = 0) {
        self.daysAgo = daysAgo
        
        print("Fetching HR data for \(daysAgo) days ago")
        
        let calendar = Calendar.current
        var date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        
        if daysAgo != 0 {
            date = calendar.startOfDay(for: date)
        }
        
        syncingDay = date
        
        let timestamp = Int(date.timeIntervalSince1970)
        let timezoneOffset = TimeZone.current.secondsFromGMT(for: date)
        let adjustedTimestamp = timestamp + timezoneOffset
        
        var subData = [UInt8](repeating: 0, count: 4)
        subData[0] = UInt8(adjustedTimestamp & 0xFF)
        subData[1] = UInt8((adjustedTimestamp >> 8) & 0xFF)
        subData[2] = UInt8((adjustedTimestamp >> 16) & 0xFF)
        subData[3] = UInt8((adjustedTimestamp >> 24) & 0xFF)
        
        sendCommand(RingConstants.CMD_SYNC_HEART_RATE, subData: subData)
    }
    
    // MARK: - Stress
    
    func fetchHistoryStress() {
        print("Fetching stress data")
        sendCommand(RingConstants.CMD_SYNC_STRESS)
    }
    
    // MARK: - SpO2
    
    func fetchHistorySpO2() {
        print("Fetching SpO2 data")
        
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral,
              let cmdCharacteristic = peripheral.services?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainServiceUUID) })?
                .characteristics?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainWriteCharacteristicUUID) })
        else {
            print("Command characteristic not found")
            return
        }
        
        let packet: [UInt8] = [
            RingConstants.CMD_BIG_DATA_V2,
            RingConstants.BIG_DATA_TYPE_SPO2,
            0x01,
            0x00,
            0xff,
            0x00,
            0xff
        ]
        
        peripheral.writeValue(Data(packet), for: cmdCharacteristic, type: .withResponse)
    }
    
    // MARK: - Sleep
    
    func fetchHistorySleep() {
        print("Fetching sleep data")
        
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral,
              let cmdCharacteristic = peripheral.services?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainServiceUUID) })?
                .characteristics?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainWriteCharacteristicUUID) })
        else {
            print("Command characteristic not found")
            return
        }
        
        let packet: [UInt8] = [
            RingConstants.CMD_BIG_DATA_V2,
            RingConstants.BIG_DATA_TYPE_SLEEP,
            0x01,
            0x00,
            0xff,
            0x00,
            0xff
        ]
        
        peripheral.writeValue(Data(packet), for: cmdCharacteristic, type: .withResponse)
    }
    
    // MARK: - HRV
    
    func fetchHistoryHRV(daysAgo: Int = 0) {
        self.daysAgo = daysAgo
        
        print("Fetching HRV data for \(daysAgo) days ago")
        
        let calendar = Calendar.current
        var date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        
        if daysAgo != 0 {
            date = calendar.startOfDay(for: date)
        }
        
        syncingDay = date
        
        var subData = [UInt8](repeating: 0, count: 4)
        subData[0] = UInt8(daysAgo & 0xFF)
        subData[1] = UInt8((daysAgo >> 8) & 0xFF)
        subData[2] = UInt8((daysAgo >> 16) & 0xFF)
        subData[3] = UInt8((daysAgo >> 24) & 0xFF)
        
        sendCommand(RingConstants.CMD_SYNC_HRV, subData: subData)
    }
    
    // MARK: - Temperature
    
    func fetchHistoryTemperature() {
        print("Fetching temperature data")
        
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral,
              let cmdCharacteristic = peripheral.services?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainServiceUUID) })?
                .characteristics?
                .first(where: { $0.uuid == CBUUID(string: RingConstants.mainWriteCharacteristicUUID) })
        else {
            print("Command characteristic not found")
            return
        }
        
        let packet: [UInt8] = [
            RingConstants.CMD_BIG_DATA_V2,
            RingConstants.BIG_DATA_TYPE_TEMPERATURE,
            0x01,
            0x00,
            0x3e,
            0x81,
            0x02
        ]
        
        peripheral.writeValue(Data(packet), for: cmdCharacteristic, type: .withResponse)
    }
    
    // MARK: - Packet Handling
    
    func handlePacket(_ packet: [UInt8]) {
        packetHandlers.handlePacket(packet)
    }
    
    // MARK: - Sync Chain
    
    func syncNextDataType() {
        if daysAgo < 7 {
            daysAgo += 1
            fetchHistoryActivity()
        } else {
            daysAgo = 0
            fetchHistoryHeartRate()
        }
    }
    
    func fetchRecordedDataFinished() {
        print("Historical data sync completed")
        
        // Auto-save to encrypted storage
        Task {
            try? await sessionManager?.saveDataToEncryptedStorage()
        }
        
        sessionManager?.syncCompletionCallback?()
        sessionManager?.syncCompletionCallback = nil
    }
}
