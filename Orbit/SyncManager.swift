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
              let cmdCharacteristic = sessionManager.bluetoothManager?.mainWriteCharacteristic
        else {
            print("Big data write characteristic not ready — V2 service may still be initialising")
            return
        }

        var packet: [UInt8] = [RingConstants.CMD_BIG_DATA_V2]
        packet.append(contentsOf: subData)
        peripheral.writeValue(Data(packet), for: cmdCharacteristic, type: .withResponse)
    }

    // MARK: - Main Sync Entry Point

    func fetchAllHistoricalData() {
        daysAgo = 0
        // NOTE: Do NOT clear the in-memory arrays here.
        // The session manager already holds the data loaded from Core Data on launch.
        // Incoming ring packets are appended/merged into those arrays, and
        // StorageManager.saveAllData() uses upsert semantics — so new records are
        // added while existing ones are preserved.
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
            // Activity done — start HR history sync (7 days).
            daysAgo = 0
            fetchHistoryHR()
        }
    }

    // MARK: - Heart Rate History (7 days, one day per request)
    //
    // The ring responds to CMD_SYNC_HEART_RATE (0x15) with a multi-packet sequence:
    //   Packet 0:  [cmd, 0x00, totalPackets]
    //   Packet 1:  [cmd, 0x01, ts_lo, ts_mid1, ts_mid2, ts_hi, hr_0, hr_1, ... hr_8,  checksum]
    //              bytes 2–5 = UTC-adjusted Unix timestamp of the sync day (little-endian int32)
    //              bytes 6–14 = 9 HR readings, each representing a 5-minute slot
    //   Packet N:  [cmd, N, hr_0, hr_1, ... hr_12, checksum]
    //              bytes 2–14 = 13 HR readings (5-minute slots)
    //   Packet 0xFF: empty / no data for that day
    //
    // Slot minutes: packet 1 covers minutes 0–44 (9 × 5), subsequent packets cover 13 × 5 min.
    // A zero byte means no measurement was taken in that slot — skip it.
    //
    // Timestamp encoding: the ring expects LOCAL midnight expressed as a UTC Unix timestamp.
    // That is: take midnight local time → add the timezone offset → encode as int32 seconds.
    // This matches the Gadgetbridge implementation exactly (ZONE_OFFSET + DST_OFFSET).

    func fetchHistoryHR() {
        print("Fetching HR history for \(daysAgo) days ago")

        let calendar = Calendar.current
        var day = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        if daysAgo != 0 {
            day = calendar.startOfDay(for: day)
        }
        syncingDay = day

        // Compute local-midnight UTC timestamp: local midnight + timezone offset
        let localMidnight = calendar.startOfDay(for: day)
        let tzOffset = TimeZone.current.secondsFromGMT(for: localMidnight)
        let adjustedTimestamp = Int32(localMidnight.timeIntervalSince1970) + Int32(tzOffset)

        let subData: [UInt8] = [
            UInt8(adjustedTimestamp & 0xFF),
            UInt8((adjustedTimestamp >> 8) & 0xFF),
            UInt8((adjustedTimestamp >> 16) & 0xFF),
            UInt8((adjustedTimestamp >> 24) & 0xFF),
        ]

        print("HR history request: day=\(localMidnight), ts=\(adjustedTimestamp)")
        sendCommand(RingConstants.CMD_SYNC_HEART_RATE, subData: subData)
    }

    func advanceHRSyncOrNext() {
        if daysAgo < 7 {
            daysAgo += 1
            fetchHistoryHR()
        } else {
            daysAgo = 0
            fetchHistoryStress()
        }
    }

    // MARK: - Stress

    func fetchHistoryStress() {
        print("Fetching stress data")
        sendCommand(RingConstants.CMD_SYNC_STRESS)
    }

    // MARK: - SpO2 (Big Data)

    func fetchHistorySpO2() {
        guard sessionManager?.bluetoothManager?.mainWriteCharacteristic != nil else {
            print("SpO2 skipped — V2 characteristic not available, advancing to Sleep")
            fetchHistorySleep()
            return
        }
        print("Fetching SpO2 data")
        sendBigDataRequest([
            RingConstants.BIG_DATA_TYPE_SPO2,
            0x01, 0x00, 0xFF, 0x00, 0xFF,
        ])
    }

    // MARK: - Sleep (Big Data)

    func fetchHistorySleep() {
        guard sessionManager?.bluetoothManager?.mainWriteCharacteristic != nil else {
            print("Sleep skipped — V2 characteristic not available, advancing to HRV")
            daysAgo = 0
            fetchHistoryHRV()
            return
        }
        print("Fetching sleep data")
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

    /// Called by PacketHandler when a day's HRV sync completes.
    /// Loops through 7 days then advances to Temperature.
    func advanceHRVSyncOrNext() {
        if daysAgo < 7 {
            fetchHistoryHRV(daysAgo: daysAgo + 1)
        } else {
            fetchHistoryTemperature()
        }
    }

    // MARK: - Temperature (Big Data)

    func fetchHistoryTemperature() {
        guard sessionManager?.bluetoothManager?.mainWriteCharacteristic != nil else {
            print("Temperature skipped — V2 characteristic not available, finishing sync")
            fetchRecordedDataFinished()
            return
        }
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

    /// V2 notify payloads can arrive fragmented at ATT level. Route continuations
    /// directly to big-data reassembly when a V2 packet is in progress.
    func handleV2Packet(_ packet: [UInt8]) {
        guard !packet.isEmpty else { return }

        if packet[0] == RingConstants.CMD_BIG_DATA_V2 || bigDataPacket != nil {
            packetHandlers.handleBigDataPacket(packet)
            return
        }

        packetHandlers.handlePacket(packet)
    }

    // MARK: - Sync Chain Completion

    func fetchRecordedDataFinished() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Historical data sync COMPLETE")
        print("   Heart Rate : \(sessionManager?.heartRateSamples.count ?? 0) samples")
        print("   HRV        : \(sessionManager?.hrvSamples.count ?? 0) samples")
        print("   Stress     : \(sessionManager?.stressSamples.count ?? 0) samples")
        print("   SpO2       : \(sessionManager?.spO2Samples.count ?? 0) samples")
        print("   Sleep      : \(sessionManager?.sleepRecords.count ?? 0) records")
        print("   Activity   : \(sessionManager?.activitySamples.count ?? 0) samples")
        print("   Temperature: \(sessionManager?.temperatureSamples.count ?? 0) samples")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        Task {
            try? await sessionManager?.saveDataToEncryptedStorage()
        }

        sessionManager?.syncCompletionCallback?()
        sessionManager?.syncCompletionCallback = nil
    }
}
