//
//  SyncManager.swift
//  Orbit
//

import CoreBluetooth
import Foundation

class SyncManager {
    weak var sessionManager: RingSessionManager?

    var syncingDay: Date?
    var daysAgo: Int = 0
    var packetsTotalNr: Int = 0
    var currentHRPacketNr: Int = 0

    var bigDataPacketSize: Int = 0
    var bigDataPacket: Data?

    var packetHandlers: PacketHandlers!

    init(sessionManager: RingSessionManager) {
        self.sessionManager = sessionManager
        packetHandlers = PacketHandlers(syncManager: self)
    }

    private func sendCommand(_ command: UInt8, subData: [UInt8] = []) {
        sessionManager?.bluetoothManager?.sendCommand(command, subData: subData)
    }

    // MARK: - Big Data Helper (sends via V2 characteristic, not UART)

    private func sendBigDataRequest(_ subData: [UInt8]) {
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral,
              let cmdCharacteristic = peripheral.services?
              .first(where: { $0.uuid == CBUUID(string: RingConstants.mainServiceUUID) })?
              .characteristics?
              .first(where: { $0.uuid == CBUUID(string: RingConstants.mainWriteCharacteristicUUID) })
        else {
            print("Big data command characteristic not found")
            return
        }

        var packet: [UInt8] = [RingConstants.CMD_BIG_DATA_V2]
        packet.append(contentsOf: subData)
        peripheral.writeValue(Data(packet), for: cmdCharacteristic, type: .withResponse)
    }

    // MARK: - Main Sync Entry Point

    func fetchAllHistoricalData() {
        daysAgo = 0
        sessionManager?.activitySamples.removeAll()
        sessionManager?.heartRateSamples.removeAll()
        sessionManager?.stressSamples.removeAll()
        sessionManager?.spO2Samples.removeAll()
        sessionManager?.sleepRecords.removeAll()
        sessionManager?.hrvSamples.removeAll()
        sessionManager?.temperatureSamples.removeAll()
        fetchHistoryActivity()
    }

    // MARK: - Activity (7 days, one day per request)

    func fetchHistoryActivity() {
        print("Fetching activity data for \(daysAgo) days ago")

        let calendar = Calendar.current
        syncingDay = calendar.date(byAdding: .day, value: -daysAgo, to: Date())

        let subData: [UInt8] = [
            UInt8(daysAgo),
            0x0F,
            0x00,
            0x5F,
            0x01,
        ]

        sendCommand(RingConstants.CMD_SYNC_ACTIVITY, subData: subData)
    }

    func advanceActivitySyncOrNext() {
        if daysAgo < 7 {
            daysAgo += 1
            fetchHistoryActivity()
        } else {
            daysAgo = 0
            fetchHistoryHeartRate()
        }
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

        let subData: [UInt8] = [
            UInt8(adjustedTimestamp & 0xFF),
            UInt8((adjustedTimestamp >> 8) & 0xFF),
            UInt8((adjustedTimestamp >> 16) & 0xFF),
            UInt8((adjustedTimestamp >> 24) & 0xFF),
        ]

        sendCommand(RingConstants.CMD_SYNC_HEART_RATE, subData: subData)
    }

    // MARK: - Stress

    func fetchHistoryStress() {
        print("Fetching stress data")
        // FIX: CMD_SYNC_STRESS = 0x37 (was 0x52, which collided with CMD_AUTO_STRESS_PREF)
        sendCommand(RingConstants.CMD_SYNC_STRESS)
    }

    // MARK: - SpO2 (Big Data)

    func fetchHistorySpO2() {
        print("Fetching SpO2 data")
        // FIX: BIG_DATA_TYPE_SPO2 = 0x2a (was 0x06)
        sendBigDataRequest([
            RingConstants.BIG_DATA_TYPE_SPO2,
            0x01, 0x00, 0xFF, 0x00, 0xFF,
        ])
    }

    // MARK: - Sleep (Big Data)

    func fetchHistorySleep() {
        print("Fetching sleep data")
        // FIX: BIG_DATA_TYPE_SLEEP = 0x27 (was 0x0A)
        sendBigDataRequest([
            RingConstants.BIG_DATA_TYPE_SLEEP,
            0x01, 0x00, 0xFF, 0x00, 0xFF,
        ])
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

        let subData: [UInt8] = [
            UInt8(daysAgo & 0xFF),
            UInt8((daysAgo >> 8) & 0xFF),
            UInt8((daysAgo >> 16) & 0xFF),
            UInt8((daysAgo >> 24) & 0xFF),
        ]

        sendCommand(RingConstants.CMD_SYNC_HRV, subData: subData)
    }

    // MARK: - Temperature (Big Data)

    func fetchHistoryTemperature() {
        print("Fetching temperature data")
        sendBigDataRequest([
            RingConstants.BIG_DATA_TYPE_TEMPERATURE,
            0x01, 0x00, 0x3E, 0x81, 0x02,
        ])
    }

    // MARK: - Packet Handling

    func handlePacket(_ packet: [UInt8]) {
        packetHandlers.handlePacket(packet)
    }

    // MARK: - Sync Chain Completion

    func fetchRecordedDataFinished() {
        print("Historical data sync completed")

        Task {
            try? await sessionManager?.saveDataToEncryptedStorage()
        }

        sessionManager?.syncCompletionCallback?()
        sessionManager?.syncCompletionCallback = nil
    }
}
