//
//  PacketHandler.swift
//  Orbit
//

import Foundation

// MARK: - PacketHandlers

class PacketHandlers {
    // MARK: - Properties

    weak var syncManager: SyncManager?

    private var sessionManager: RingSessionManager? {
        syncManager?.sessionManager
    }

    // MARK: - Initialization

    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }

    // MARK: - Main Packet Router

    func handlePacket(_ packet: [UInt8]) {
        guard packet.count > 0 else { return }

        let command = packet[0]

        switch command {
        case RingConstants.CMD_SET_DATE_TIME:
            print("Received set date/time response")

        case RingConstants.CMD_BATTERY:
            handleBatteryResponse(packet)

        case RingConstants.CMD_PHONE_NAME:
            print("Received phone name response")

        case RingConstants.CMD_PREFERENCES:
            print("Received user preferences response")

        case RingConstants.CMD_SYNC_HEART_RATE: // 0x15
            handleHRHistoryPacket(packet)

        case RingConstants.CMD_AUTO_HR_PREF: // 0x16
            handleHeartRateSettingsResponse(packet)

        case RingConstants.CMD_REALTIME_HEART_RATE: // 0x1e — unused, log only
            print("Received 0x1E packet (ignored): \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")

        case RingConstants.CMD_GOALS: // 0x21
            handleGoalsResponse(packet)

        case RingConstants.CMD_AUTO_SPO2_PREF: // 0x2c
            handleSpO2SettingsResponse(packet)

        case RingConstants.CMD_PACKET_SIZE: // 0x2f
            if packet.count > 1 {
                print("Received packet size indicator: \(packet[1]) bytes")
            }

        case RingConstants.CMD_AUTO_STRESS_PREF: // 0x36
            if packet.count > 1 && packet[1] != RingConstants.PREF_WRITE {
                handleStressSettingsResponse(packet)
            }

        case RingConstants.CMD_SYNC_STRESS: // 0x37
            handleStressHistoryPacket(packet)

        case RingConstants.CMD_AUTO_HRV_PREF: // 0x38
            if packet.count > 1 && packet[1] != RingConstants.PREF_WRITE {
                handleHRVSettingsResponse(packet)
            }

        case RingConstants.CMD_SYNC_HRV: // 0x39
            handleHRVHistoryPacket(packet)

        case RingConstants.CMD_AUTO_TEMP_PREF: // 0x3a
            if packet.count > 1 && packet[1] == 0x03 {
                handleTemperatureSettingsResponse(packet)
            }

        case RingConstants.CMD_SYNC_ACTIVITY: // 0x43
            handleActivityHistoryPacket(packet)

        case RingConstants.CMD_FIND_DEVICE: // 0x50
            print("Received find device response")

        case RingConstants.CMD_MANUAL_HEART_RATE: // 0x69
            handleManualHeartRateResponse(packet)

        case RingConstants.CMD_NOTIFICATION: // 0x73
            handleNotificationPacket(packet)

        case RingConstants.CMD_BIG_DATA_V2: // 0xbc
            handleBigDataPacket(packet)

        default:
            print("Unrecognized packet command: 0x\(String(format: "%02X", command))")
        }
    }

    // MARK: - Basic Response Handlers

    private func handleBatteryResponse(_ packet: [UInt8]) {
        guard packet.count >= 3, let sessionManager = sessionManager else { return }

        let level = Int(packet[1])
        let charging = packet[2] == 1

        print("Battery: \(level)%, charging: \(charging)")

        let batteryInfo = BatteryInfo(batteryLevel: level, charging: charging)
        sessionManager.currentBatteryInfo = batteryInfo
        sessionManager.batteryStatusCallback?(batteryInfo)
        sessionManager.batteryStatusCallback = nil

        if level <= 20 && !charging {
            sessionManager.sendLowBatteryNotification(level: level)
        }
    }

    // MARK: - Heart Rate History Handler
    //
    // Multi-packet protocol:
    //   Packet [cmd, 0xFF]:             no data for this day → advance
    //   Packet [cmd, 0x00, totalPkts]:  header — store total count
    //   Packet [cmd, 1, ts(4), hr×9]:   first data packet; bytes 2–5 = UTC timestamp (unused for
    //                                   time reconstruction — we use syncingDay instead); bytes 6–14
    //                                   = 9 HR readings for minutes 0–44 (5-min slots)
    //   Packet [cmd, N, hr×13]:         subsequent data packets; bytes 2–14 = 13 HR readings
    //
    // Slot time = (minutesInPreviousPackets + (byteIndex - startByte) * 5) minutes from
    // start-of-day on syncingDay. Zero bytes mean no measurement — skip them.
    //
    // Each sample is written immediately to Core Data (mergeHeartRate) so it survives
    // disconnects and backgrounding without waiting for the full sync chain to complete.

    private func handleHRHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetNr = Int(packet[1])

        // 0xFF = empty / no data for this day
        if packetNr == 0xFF {
            print("Empty HR history for day \(syncManager.daysAgo)")
            syncManager.advanceHRSyncOrNext()
            return
        }

        // Packet 0 = header, carries total packet count
        if packetNr == 0 {
            if packet.count > 2 {
                syncManager.packetsTotalNr = Int(packet[2])
            }
            print("HR day \(syncManager.daysAgo): expecting \(syncManager.packetsTotalNr) packets")
            return
        }

        print("HR packet \(packetNr)/\(syncManager.packetsTotalNr) (day \(syncManager.daysAgo))")

        guard let baseDay = syncManager.syncingDay else {
            print("HR: no syncingDay set — skipping")
            return
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: baseDay)

        // Byte layout:
        //   Packet 1: [cmd, 0x01, ts_b0, ts_b1, ts_b2, ts_b3, hr_0..hr_8, checksum]
        //             startByte = 6, covers 9 slots (minutes 0–44)
        //   Packet N: [cmd, N, hr_0..hr_12, checksum]
        //             startByte = 2, covers 13 slots
        let startByte = packetNr == 1 ? 6 : 2
        let slotsInPacket1 = 9
        let slotsPerPacket = 13

        var minutesOffset: Int
        if packetNr == 1 {
            minutesOffset = 0
        } else {
            minutesOffset = slotsInPacket1 * 5 + (packetNr - 2) * slotsPerPacket * 5
        }

        var newSamples: [HeartRateSample] = []

        // Exclude last byte (checksum)
        let endByte = packet.count - 1
        for i in startByte ..< endByte {
            let hr = Int(packet[i])
            guard hr > 0 else { continue }   // 0x00 = no measurement

            let minuteOfDay = minutesOffset + (i - startByte) * 5
            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = minuteOfDay / 60
            components.minute = minuteOfDay % 60
            components.second = 0

            guard let sampleDate = calendar.date(from: components) else { continue }
            print("  HR: \(hr) bpm @ \(sampleDate)")

            let sample = HeartRateSample(timestamp: sampleDate, heartRate: hr)
            newSamples.append(sample)
        }

        // Merge into in-memory array
        for sample in newSamples {
            if let idx = sessionManager.heartRateSamples.firstIndex(where: { $0.timestamp == sample.timestamp }) {
                sessionManager.heartRateSamples[idx] = sample
            } else {
                sessionManager.heartRateSamples.append(sample)
            }
        }

        // Persist immediately so samples survive disconnect / backgrounding
        if !newSamples.isEmpty {
            Task {
                try? await sessionManager.storageManager.mergeHeartRate(newSamples)
            }
        }

        // Advance to next day when this day's sequence is complete.
        // packetsTotalNr is the total packet count including the header (packet 0),
        // so the last data packet number is packetsTotalNr - 1.
        // (Stress and HRV handlers already use this convention correctly.)
        if packetNr == syncManager.packetsTotalNr - 1 {
            print("HR day \(syncManager.daysAgo) complete: \(sessionManager.heartRateSamples.count) total samples")
            sessionManager.heartRateHistoryCallback?(sessionManager.heartRateSamples)
            syncManager.advanceHRSyncOrNext()
        }
    }

    // MARK: - Manual / Live Heart Rate Response
    //
    // Triggered by NOTIFICATION_NEW_HR_DATA → CMD_MANUAL_HEART_RATE.
    // Each response is persisted immediately to Core Data rather than waiting for sync
    // completion — this ensures auto-HR readings are never lost on disconnect.

    private func handleManualHeartRateResponse(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        let errorCode = Int(packet[2])
        let hrResponse = Int(packet[3])

        switch errorCode {
        case 0:
            print("Manual HR: \(hrResponse) bpm")
            if hrResponse > 0 {
                sessionManager.latestMeasuredHeartRate = hrResponse
                let sample = HeartRateSample(timestamp: Date(), heartRate: hrResponse)
                sessionManager.heartRateSamples.append(sample)

                // Persist immediately — don't rely on sync-completion callback
                Task {
                    try? await sessionManager.storageManager.mergeHeartRate([sample])
                }
            }
        case 1:
            print("HR error: ring worn incorrectly")
        case 2:
            print("HR error: temporary error / missing data")
        default:
            print("HR error code: \(errorCode)")
        }
    }

    // MARK: - Notification Handlers

    private func handleNotificationPacket(_ packet: [UInt8]) {
        guard packet.count > 1 else { return }

        let notificationType = packet[1]

        switch notificationType {
        case RingConstants.NOTIFICATION_NEW_HR_DATA: // 0x01
            // The ring pushes this notification each time it completes an auto HR measurement.
            // Skip during an active sync — the sync chain will collect HR history anyway,
            // and firing a manual read mid-sync adds unnecessary BLE traffic.
            guard syncManager?.sessionManager?.isSyncing != true else {
                print("New HR data available — skipping manual read (sync in progress)")
                break
            }
            print("New HR data available — requesting measurement")
            sessionManager?.commandManager.triggerManualHeartRate()

        case RingConstants.NOTIFICATION_NEW_SPO2_DATA: // 0x03
            print("New SpO2 data available")

        case RingConstants.NOTIFICATION_NEW_STEPS_DATA: // 0x04
            print("New steps data available")

        case RingConstants.NOTIFICATION_BATTERY_LEVEL: // 0x0c
            guard packet.count >= 4, let sessionManager = sessionManager else { return }
            let level = Int(packet[2])
            let charging = packet[3] == 1
            print("Battery notification: \(level)%, charging: \(charging)")
            let batteryInfo = BatteryInfo(batteryLevel: level, charging: charging)
            sessionManager.currentBatteryInfo = batteryInfo

        case RingConstants.NOTIFICATION_LIVE_ACTIVITY: // 0x12
            guard let sessionManager = sessionManager, packet.count >= 11 else { break }
            let liveSteps    = (Int(packet[2]) << 16) | (Int(packet[3]) << 8) | Int(packet[4])
            // Raw value is in 0.001 kcal units (total-day energy including BMR).
            // Divide by 100 to get kcal (previously /10 was 10× too high).
            let liveCalories = ((Int(packet[5]) << 16) | (Int(packet[6]) << 8) | Int(packet[7])) / 100
            let liveDistance = (Int(packet[8]) << 16) | (Int(packet[9]) << 8) | Int(packet[10])
            print("Live activity push (cumulative today): \(liveSteps) steps, \(liveCalories) kcal, \(liveDistance)m")
            sessionManager.liveStepTotal    = liveSteps
            sessionManager.liveCalorieTotal = liveCalories
            sessionManager.liveDistanceTotal = liveDistance

        default:
            print("Unrecognized notification: 0x\(String(format: "%02X", notificationType))")
        }
    }

    // MARK: - Settings Response Handlers

    private func handleHeartRateSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 4 else { return }
        guard packet[1] != RingConstants.PREF_WRITE else { return }
        let enabled = packet[2] == 0x01
        let intervalMins = Int(packet[3])
        print("HR settings: enabled=\(enabled), interval=\(intervalMins) min")
    }

    private func handleSpO2SettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 3 else { return }
        let enabled = packet[2] == 0x01
        print("SpO2 all-day: \(enabled)")
    }

    private func handleStressSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 3 else { return }
        let enabled = packet[2] == 0x01
        print("Stress monitoring: \(enabled)")
    }

    private func handleHRVSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 3 else { return }
        let enabled = packet[2] == 0x01
        print("HRV all-day: \(enabled)")
    }

    private func handleTemperatureSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 4 else { return }
        let enabled = packet[3] == 0x01
        print("Temperature all-day: \(enabled)")
    }

    private func handleGoalsResponse(_ packet: [UInt8]) {
        guard packet.count >= 15 else { return }

        let steps = Int(packet[2]) | (Int(packet[3]) << 8) | (Int(packet[4]) << 16)
        let caloriesRaw = Int(packet[5]) | (Int(packet[6]) << 8) | (Int(packet[7]) << 16)
        let calories = caloriesRaw / 1000
        let distance = Int(packet[8]) | (Int(packet[9]) << 8) | (Int(packet[10]) << 16)
        let sport = Int(packet[11]) | (Int(packet[12]) << 8)
        let sleep = Int(packet[13]) | (Int(packet[14]) << 8)

        print("Goals: \(steps) steps, \(calories) kcal (raw \(caloriesRaw)), \(distance)m, \(sport)min sport, \(sleep)min sleep")
    }
}

// MARK: - Historical Data Handlers

extension PacketHandlers {
    func handleStressHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetNr = Int(packet[1])

        if packetNr == 0xFF {
            print("Empty stress history, proceeding to SpO2")
            syncManager.fetchHistorySpO2()
            return
        }

        if packetNr == 0 {
            if packet.count > 2 {
                syncManager.packetsTotalNr = Int(packet[2])
            } else {
                syncManager.packetsTotalNr = 4
            }
            print("Stress history: expecting \(syncManager.packetsTotalNr) packets")
            return
        }

        print("Stress packet \(packetNr)/\(syncManager.packetsTotalNr)")

        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: Date())

        let startValue = packetNr == 1 ? 3 : 2
        var minutesInPreviousPackets = 0
        if packetNr > 1 {
            minutesInPreviousPackets = 12 * 30 + (packetNr - 2) * 13 * 30
        }

        for i in startValue ..< (packet.count - 1) {
            if packet[i] != 0x00 {
                let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 30
                var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                components.hour = minuteOfDay / 60
                components.minute = minuteOfDay % 60
                components.second = 0

                if let sampleDate = calendar.date(from: components) {
                    let sample = StressSample(timestamp: sampleDate, stressLevel: Int(packet[i]))
                    if !sessionManager.stressSamples.contains(where: { $0.timestamp == sample.timestamp }) {
                        sessionManager.stressSamples.append(sample)
                    } else {
                        sessionManager.stressSamples = sessionManager.stressSamples.map {
                            $0.timestamp == sample.timestamp ? sample : $0
                        }
                    }
                }
            }
        }

        if packetNr == syncManager.packetsTotalNr - 1 {
            print("Stress sync complete: \(sessionManager.stressSamples.count) samples")
            sessionManager.stressHistoryCallback?(sessionManager.stressSamples)
            syncManager.fetchHistorySpO2()
        }
    }

    func handleActivityHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 12,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetType = Int(packet[1])

        if packetType == 0xFF {
            print("Empty activity history")
            syncManager.advanceActivitySyncOrNext()
            return
        }

        if packetType == 0xF0 { return }

        let calendar = Calendar.current

        let month = Int(packet[2])
        let day   = Int(packet[3])

        let contextYear: Int
        if let syncDay = syncManager.syncingDay {
            contextYear = calendar.component(.year, from: syncDay)
        } else {
            contextYear = calendar.component(.year, from: Date())
        }

        let quarterIndex = Int(packet[4])
        let hour         = quarterIndex / 4
        let quarter      = quarterIndex % 4

        var components = DateComponents()
        components.year   = contextYear
        components.month  = month
        components.day    = day
        components.hour   = hour
        components.minute = quarter * 15
        components.second = 0

        guard let date = calendar.date(from: components) else { return }

        let steps       = Int(packet[9])  | (Int(packet[10]) << 8)
        // Raw calorie value is in units of 0.01 kcal (active calories only).
        // Divide by 100 to get kcal. This aligns with the live-push (0x73/0x12)
        // which stores total-day energy in 0.001 kcal units divided by 100 = kcal.
        let caloriesRaw = Int(packet[7])  | (Int(packet[8]) << 8)
        let calories    = caloriesRaw / 100
        let distance    = Int(packet[11]) | (Int(packet[12]) << 8)

        let sample = ActivitySample(timestamp: date, steps: steps, distance: distance, calories: calories)

        if let index = sessionManager.activitySamples.firstIndex(where: { $0.timestamp == sample.timestamp }) {
            sessionManager.activitySamples[index] = sample
        } else {
            sessionManager.activitySamples.append(sample)
        }

        let currentPacket = Int(packet[5])
        let totalPackets  = Int(packet[6])

        if currentPacket == totalPackets - 1 {
            print("Activity sync complete (\(syncManager.daysAgo) days ago)")
            sessionManager.activityHistoryCallback?(sessionManager.activitySamples)
            // Do NOT reset live totals here — historical sync is the source of truth
            syncManager.advanceActivitySyncOrNext()
        }
    }

    func handleHRVHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetNr = Int(packet[1])

        if packetNr == 0xFF {
            print("Empty HRV history for day \(syncManager.daysAgo)")
            syncManager.advanceHRVSyncOrNext()
            return
        }

        if packetNr == 0 {
            if packet.count > 2 {
                syncManager.packetsTotalNr = Int(packet[2])
            } else {
                syncManager.packetsTotalNr = 4
            }
            print("HRV day \(syncManager.daysAgo): expecting \(syncManager.packetsTotalNr) packets")
            return
        }

        print("HRV packet \(packetNr)/\(syncManager.packetsTotalNr) (day \(syncManager.daysAgo))")

        let calendar = Calendar.current
        let baseDay: Date
        if syncManager.daysAgo != 0 {
            let shifted = calendar.date(byAdding: .day, value: -syncManager.daysAgo, to: Date())!
            baseDay = calendar.startOfDay(for: shifted)
        } else {
            baseDay = calendar.startOfDay(for: Date())
        }

        let startValue = packetNr == 1 ? 3 : 2
        var minutesInPreviousPackets = 0
        if packetNr > 1 {
            minutesInPreviousPackets = 12 * 30 + (packetNr - 2) * 13 * 30
        }

        for i in startValue ..< (packet.count - 1) {
            if packet[i] != 0x00 {
                let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 30
                var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                components.hour   = minuteOfDay / 60
                components.minute = minuteOfDay % 60
                components.second = 0

                if let sampleDate = calendar.date(from: components) {
                    let sample = HRVSample(timestamp: sampleDate, hrvValue: Int(packet[i]))
                    print("  HRV: \(sample.hrvValue)ms @ \(sampleDate)")
                    if !sessionManager.hrvSamples.contains(where: { $0.timestamp == sample.timestamp }) {
                        sessionManager.hrvSamples.append(sample)
                    } else {
                        sessionManager.hrvSamples = sessionManager.hrvSamples.map {
                            $0.timestamp == sample.timestamp ? sample : $0
                        }
                    }
                }
            }
        }

        if packetNr == syncManager.packetsTotalNr - 1 {
            print("HRV day \(syncManager.daysAgo) complete: \(sessionManager.hrvSamples.count) total samples")
            sessionManager.hrvHistoryCallback?(sessionManager.hrvSamples)
            syncManager.advanceHRVSyncOrNext()
        }
    }
}

// MARK: - Big Data Handlers

extension PacketHandlers {
    func handleBigDataPacket(_ packet: [UInt8]) {
        guard packet.count >= 4, let syncManager = syncManager else { return }

        let packetLength = Int(packet[2]) | (Int(packet[3]) << 8)

        if var buffered = syncManager.bigDataPacket {
            buffered.append(Data(packet))
            syncManager.bigDataPacket = buffered

            let expectedTotal = syncManager.bigDataPacketSize + 6
            if buffered.count >= expectedTotal {
                let completePacket = [UInt8](buffered)
                syncManager.bigDataPacket = nil
                print("Big data reassembled: \(completePacket.count) bytes")
                dispatchBigData(completePacket, syncManager: syncManager)
            } else {
                print("Big data still buffering: \(buffered.count)/\(expectedTotal) bytes")
            }
            return
        }

        if packet.count < packetLength + 6 {
            print("Big data incomplete (\(packet.count)/\(packetLength + 6)), buffering...")
            syncManager.bigDataPacketSize = packetLength
            syncManager.bigDataPacket = Data(packet)
            return
        }

        dispatchBigData(packet, syncManager: syncManager)
    }

    private func dispatchBigData(_ packet: [UInt8], syncManager: SyncManager) {
        guard packet.count > 1 else { return }

        let dataType = packet[1]

        switch dataType {
        case RingConstants.BIG_DATA_TYPE_SPO2:
            handleSpO2History(packet)
            syncManager.fetchHistorySleep()

        case RingConstants.BIG_DATA_TYPE_SLEEP:
            handleSleepHistory(packet)
            syncManager.daysAgo = 0
            syncManager.fetchHistoryHRV()

        case RingConstants.BIG_DATA_TYPE_TEMPERATURE:
            handleTemperatureHistory(packet)
            syncManager.fetchRecordedDataFinished()

        default:
            print("Unrecognized big data type: 0x\(String(format: "%02X", dataType))")
        }
    }

    func handleSpO2History(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        var incomingSamples: [SpO2Sample] = []

        let length = Int(packet[2]) | (Int(packet[3]) << 8)
        var index = 6
        var daysAgo = -1
        let calendar = Calendar.current

        print("SpO2 raw data: \(length) bytes, packet total \(packet.count) bytes")

        while daysAgo != 0, (index - 6) < length {
            guard index < packet.count else { break }
            daysAgo = Int(packet[index])
            index += 1

            let baseDay = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            )

            for hour in 0 ... 23 {
                guard index + 1 < packet.count else { break }

                let spo2Min = Float(packet[index]); index += 1
                let spo2Max = Float(packet[index]); index += 1

                if spo2Min > 0, spo2Max > 0 {
                    var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                    components.hour   = hour
                    components.minute = 0
                    components.second = 0

                    if let hourDate = calendar.date(from: components) {
                        let avgSpO2 = Int(round((spo2Min + spo2Max) / 2.0))
                        let sample = SpO2Sample(timestamp: hourDate, spO2: avgSpO2)
                        incomingSamples.append(sample)
                        print("  SpO2 \(daysAgo)d ago h\(hour): min=\(Int(spo2Min))% max=\(Int(spo2Max))% avg=\(avgSpO2)% @ \(hourDate)")
                    }
                }

                if (index - 6) >= length { break }
            }
        }

        let incomingTimestamps = Set(incomingSamples.map { $0.timestamp })
        let kept = sessionManager.spO2Samples.filter { !incomingTimestamps.contains($0.timestamp) }
        sessionManager.spO2Samples = (kept + incomingSamples).sorted { $0.timestamp < $1.timestamp }

        print("SpO2 sync complete: \(sessionManager.spO2Samples.count) samples (\(incomingSamples.count) from ring)")
        sessionManager.spO2HistoryCallback?(sessionManager.spO2Samples)
    }

    func handleSleepHistory(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        var incomingRecords: [SleepRecord] = []
        let now = Date()
        let earliestAllowed = now.addingTimeInterval(-180 * 86400)
        let latestAllowed = now.addingTimeInterval(2 * 86400)

        let packetLength = Int(packet[2]) | (Int(packet[3]) << 8)

        if packetLength < 2 {
            print("Empty sleep data")
            return
        }

        let daysInPacket = Int(packet[6])
        print("Sleep data for \(daysInPacket) days")

        var index = 7
        let calendar = Calendar.current

        for _ in 1 ... daysInPacket {
            guard index + 5 < packet.count else { break }

            let daysAgo  = Int(packet[index]); index += 1
            let dayBytes = Int(packet[index]); index += 1

            let sleepStart = Int(packet[index]) | (Int(packet[index + 1]) << 8); index += 2
            let sleepEnd   = Int(packet[index]) | (Int(packet[index + 1]) << 8); index += 2

            // Protocol: daysAgo = how many days ago the person WOKE UP.
            // sleepStart and sleepEnd are both in minutes-from-midnight of the WAKE DAY.
            // This matches the Gadgetbridge implementation exactly.
            //
            // If sleepStart > sleepEnd the session crossed midnight:
            //   sessionStart = wakeDayMidnight + (sleepStart - 1440) minutes   → previous evening
            //   sessionEnd   = wakeDayMidnight + sleepEnd minutes               → morning
            //
            // If sleepStart <= sleepEnd it's a same-night session (nap, post-midnight nap):
            //   sessionStart = wakeDayMidnight + sleepStart minutes
            //   sessionEnd   = wakeDayMidnight + sleepEnd minutes
            let wakeDayMidnight = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            )

            let sessionStart: Date
            if sleepStart > sleepEnd {
                // Crossed midnight: start offset is sleepStart - 1440 (negative → previous night)
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart - 1440, to: wakeDayMidnight)!
            } else {
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart, to: wakeDayMidnight)!
            }

            let sessionEnd = calendar.date(byAdding: .minute, value: sleepEnd, to: wakeDayMidnight)!

            print("Sleep: \(sessionStart) → \(sessionEnd)")

            var sleepStageTime = sessionStart

            // Stage data: pairs of [type, minutes] starting at offset 4 in the day block
            for _ in stride(from: 4, to: dayBytes, by: 2) {
                guard index + 1 < packet.count else { break }

                let stageTypeByte = packet[index]
                let sleepMinutes  = Int(packet[index + 1])
                index += 2

                guard sleepMinutes > 0 else { continue }

                let sleepType: SleepRecord.SleepType
                switch stageTypeByte {
                case RingConstants.SLEEP_TYPE_LIGHT:  sleepType = .light
                case RingConstants.SLEEP_TYPE_DEEP:   sleepType = .deep
                case RingConstants.SLEEP_TYPE_REM:    sleepType = .rem
                case RingConstants.SLEEP_TYPE_AWAKE:  sleepType = .awake
                default:                              sleepType = .awake
                }

                let stageEnd = calendar.date(byAdding: .minute, value: sleepMinutes, to: sleepStageTime)!
                let boundedStageEnd = min(stageEnd, sessionEnd)

                if stageEnd > sessionEnd {
                    print("Sleep stage exceeds session end — data may be corrupt")
                }

                if boundedStageEnd > sleepStageTime,
                   sleepStageTime >= earliestAllowed,
                   boundedStageEnd <= latestAllowed
                {
                    let record = SleepRecord(startTime: sleepStageTime, endTime: boundedStageEnd, sleepType: sleepType)
                    incomingRecords.append(record)
                    print("  Sleep stage: \(sleepType) \(sleepMinutes)min [\(sleepStageTime) → \(boundedStageEnd)]")
                }

                sleepStageTime = boundedStageEnd
                if sleepStageTime >= sessionEnd { break }
            }
        }

        // Merge: keep existing records outside the incoming window; purge future-date artifacts.
        // Also de-duplicate by start timestamp to avoid duplicated stage segments inflating totals.
        let incomingUnique = Dictionary(
            incomingRecords.map { ($0.startTime, $0) },
            uniquingKeysWith: { lhs, rhs in
                rhs.endTime > lhs.endTime ? rhs : lhs
            }
        ).values
        let incoming = Array(incomingUnique)
        let incomingTimestamps = Set(incoming.map { $0.startTime })
        let kept = sessionManager.sleepRecords.filter {
            !incomingTimestamps.contains($0.startTime) &&
                $0.startTime >= earliestAllowed &&
                $0.startTime < latestAllowed
        }
        sessionManager.sleepRecords = (kept + incoming).sorted { $0.startTime < $1.startTime }

        print("Sleep sync complete: \(sessionManager.sleepRecords.count) records (\(incoming.count) from ring)")
        sessionManager.sleepHistoryCallback?(sessionManager.sleepRecords)
    }

    func handleTemperatureHistory(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        var incomingSamples: [TemperatureSample] = []

        let length = Int(packet[2]) | (Int(packet[3]) << 8)

        if length < 50 {
            print("Invalid temperature data length: \(length)")
            return
        }

        var index = 6
        var daysAgo = -1
        let calendar = Calendar.current

        while daysAgo != 0, (index - 6) < length {
            guard index < packet.count else { break }
            daysAgo = Int(packet[index]); index += 1
            index += 1 // skip one unknown byte (always 0x1e)

            let baseDay = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            )

            for hour in 0 ... 23 {
                guard index + 1 < packet.count else { break }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                components.second = 0

                let temp00 = Float(packet[index]); index += 1
                let temp30 = Float(packet[index]); index += 1

                // Raw value encodes °C as (value / 10) + 20
                if temp00 > 0 {
                    components.hour   = hour
                    components.minute = 0
                    if let t = calendar.date(from: components) {
                        let celsius = Double((temp00 / 10.0) + 20.0)
                        incomingSamples.append(TemperatureSample(timestamp: t, temperature: celsius))
                    }
                }

                if temp30 > 0 {
                    components.hour   = hour
                    components.minute = 30
                    if let t = calendar.date(from: components) {
                        let celsius = Double((temp30 / 10.0) + 20.0)
                        incomingSamples.append(TemperatureSample(timestamp: t, temperature: celsius))
                    }
                }

                if (index - 6) >= length { break }
            }
        }

        let incomingTimestamps = Set(incomingSamples.map { $0.timestamp })
        let kept = sessionManager.temperatureSamples.filter { !incomingTimestamps.contains($0.timestamp) }
        sessionManager.temperatureSamples = (kept + incomingSamples).sorted { $0.timestamp < $1.timestamp }

        print("Temperature sync complete: \(sessionManager.temperatureSamples.count) samples (\(incomingSamples.count) from ring)")
        sessionManager.temperatureHistoryCallback?(sessionManager.temperatureSamples)
    }
}
