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
            handleHeartRateHistoryPacket(packet)

        case RingConstants.CMD_AUTO_HR_PREF: // 0x16
            handleHeartRateSettingsResponse(packet)

        case RingConstants.CMD_REALTIME_HEART_RATE: // 0x1e — realtime HR stream
            // FIX: route realtime HR to RealtimeManager, not PacketHandler
            sessionManager?.realtimeManager?.handleRealtimeHeartRatePacket(packet)

        case RingConstants.CMD_GOALS: // 0x21
            handleGoalsResponse(packet)

        case RingConstants.CMD_AUTO_SPO2_PREF: // 0x2c
            handleSpO2SettingsResponse(packet)

        case RingConstants.CMD_PACKET_SIZE: // 0x2f
            if packet.count > 1 {
                print("Received packet size indicator: \(packet[1]) bytes")
            }

        case RingConstants.CMD_AUTO_STRESS_PREF: // 0x36
            // FIX: distinguish read-response vs write-ack
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
    }

    private func handleManualHeartRateResponse(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        let errorCode = Int(packet[2])
        let hrResponse = Int(packet[3])

        switch errorCode {
        case 0:
            print("Manual HR: \(hrResponse) bpm")
            if hrResponse > 0 {
                sessionManager.realtimeHeartRate = hrResponse
                let sample = HeartRateSample(timestamp: Date(), heartRate: hrResponse)
                sessionManager.heartRateSamples.append(sample)
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
            print("New HR data available (ring has stored history to sync)")

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
            // FIX: route to RealtimeManager which owns the live-activity state machine
            sessionManager?.realtimeManager?.handleLiveActivityPacket(packet)

        default:
            print("Unrecognized notification: 0x\(String(format: "%02X", notificationType))")
        }
    }

    // MARK: - Settings Response Handlers

    private func handleHeartRateSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 4 else { return }
        // FIX: ignore write-ack (byte[1] == PREF_WRITE)
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

        // FIX: little-endian 3-byte reads (GB uses toUint32 with byte order value[2],value[3],value[4])
        let steps = Int(packet[2]) | (Int(packet[3]) << 8) | (Int(packet[4]) << 16)
        let calories = Int(packet[5]) | (Int(packet[6]) << 8) | (Int(packet[7]) << 16)
        let distance = Int(packet[8]) | (Int(packet[9]) << 8) | (Int(packet[10]) << 16)
        let sport = Int(packet[11]) | (Int(packet[12]) << 8)
        let sleep = Int(packet[13]) | (Int(packet[14]) << 8)

        print("Goals: \(steps) steps, \(calories) cal, \(distance)m, \(sport)min sport, \(sleep)min sleep")
    }
}

// MARK: - Historical Data Handlers

extension PacketHandlers {
    func handleHeartRateHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetNr = Int(packet[1])

        if packetNr == 0xFF {
            print("Empty HR history")
            return
        }

        if packetNr == 0 {
            syncManager.packetsTotalNr = Int(packet[2])
            print("HR packet 0/\(syncManager.packetsTotalNr)")
            syncManager.currentHRPacketNr = 0
            sessionManager.heartRateSamples.removeAll()
        } else {
            print("HR packet \(packetNr)/\(syncManager.packetsTotalNr)")

            guard let syncDay = syncManager.syncingDay else { return }
            let calendar = Calendar.current

            // FIX: first packet has 9 samples at 5-min intervals (byte 6 onwards),
            // subsequent packets have 13 samples starting from byte 2.
            let startValue = packetNr == 1 ? 6 : 2
            var minutesInPreviousPackets = 0

            if packetNr > 1 {
                minutesInPreviousPackets = 9 * 5
                minutesInPreviousPackets += (packetNr - 2) * 13 * 5
            }

            for i in startValue ..< (packet.count - 1) {
                if packet[i] != 0x00 {
                    let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 5

                    var components = calendar.dateComponents([.year, .month, .day], from: syncDay)
                    components.hour = minuteOfDay / 60
                    components.minute = minuteOfDay % 60
                    components.second = 0

                    if let sampleDate = calendar.date(from: components) {
                        let sample = HeartRateSample(timestamp: sampleDate, heartRate: Int(packet[i]))
                        sessionManager.heartRateSamples.append(sample)
                    }
                }
            }

            syncManager.currentHRPacketNr = packetNr

            if packetNr == syncManager.packetsTotalNr - 1 {
                print("HR sync complete: \(sessionManager.heartRateSamples.count) samples")
                sessionManager.heartRateHistoryCallback?(sessionManager.heartRateSamples)
            }
        }
    }

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
            print("Received initial stress history response")
            return
        }

        print("Stress packet \(packetNr)")

        let calendar = Calendar.current
        // FIX: stress is always for today (Gadgetbridge uses Calendar.getInstance() with no offset)
        let baseDay = calendar.startOfDay(for: Date())

        let startValue = packetNr == 1 ? 3 : 2
        var minutesInPreviousPackets = 0

        if packetNr > 1 {
            minutesInPreviousPackets = 12 * 30
            minutesInPreviousPackets += (packetNr - 2) * 13 * 30
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
                    sessionManager.stressSamples.append(sample)
                }
            }
        }

        // FIX: stress sync is complete at packet 4, then proceed to SpO2
        if packetNr == 4 {
            print("Stress sync complete: \(sessionManager.stressSamples.count) samples")
            sessionManager.stressHistoryCallback?(sessionManager.stressSamples)
            syncManager.fetchHistorySpO2()
        }
    }

    func handleActivityHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetType = Int(packet[1])

        // FIX: 0xff = empty, 0xf0 = initial header (skip both)
        if packetType == 0xFF {
            print("Empty activity history")
            syncManager.advanceActivitySyncOrNext()
            return
        }

        if packetType == 0xF0 { return }

        let calendar = Calendar.current

        // QUIRK: Month and day are plain binary (not BCD).
        // e.g. Feb 16 → packet[2]=0x02=2, packet[3]=0x10=16 (decimal 16, NOT BCD "10"=10)
        //
        // QUIRK: The year byte (packet[1]) is unreliable — the ring sends 0x00 because
        // activity records do not store the year. Derive the year from syncingDay
        let month = Int(packet[2])
        let day = Int(packet[3])

        let contextYear: Int
        if let syncDay = syncManager.syncingDay {
            contextYear = calendar.component(.year, from: syncDay)
        } else {
            contextYear = calendar.component(.year, from: Date())
        }

        var components = DateComponents()
        components.year = contextYear
        components.month = month
        components.day = day
        // QUIRK: hour is transmitted as "nth quarter of the day" (0-95), not 0-23.
        components.hour = Int(packet[4]) / 4
        components.minute = 0
        components.second = 0

        guard let date = calendar.date(from: components) else { return }

        let steps = Int(packet[9]) | (Int(packet[10]) << 8)
        let calories = (Int(packet[7]) | (Int(packet[8]) << 8)) / 10
        let distance = Int(packet[11]) | (Int(packet[12]) << 8)

        print("Activity: \(date) - \(steps) steps, \(calories) cal, \(distance)m")

        let sample = ActivitySample(timestamp: date, steps: steps, distance: distance, calories: calories)
        sessionManager.activitySamples.append(sample)

        let currentPacket = Int(packet[5])
        let totalPackets = Int(packet[6])

        if currentPacket == totalPackets - 1 {
            print("Activity sync complete (\(syncManager.daysAgo) days ago): \(sessionManager.activitySamples.count) samples")
            sessionManager.activityHistoryCallback?(sessionManager.activitySamples)
            syncManager.advanceActivitySyncOrNext()
        }
    }

    func handleHRVHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }

        let packetNr = Int(packet[1])

        if packetNr == 0xFF {
            print("Empty HRV history, proceeding to temperature")
            syncManager.fetchHistoryTemperature()
            return
        }

        if packetNr == 0 {
            let totalNr = Int(packet[2])
            print("HRV history packet 0 of \(totalNr)")
            return
        }

        print("HRV packet \(packetNr)")

        let calendar = Calendar.current
        var baseDay: Date

        if syncManager.daysAgo != 0 {
            let shifted = calendar.date(byAdding: .day, value: -syncManager.daysAgo, to: Date())!
            baseDay = calendar.startOfDay(for: shifted)
        } else {
            baseDay = calendar.startOfDay(for: Date())
        }

        let startValue = packetNr == 1 ? 3 : 2
        var minutesInPreviousPackets = 0

        if packetNr > 1 {
            minutesInPreviousPackets = 12 * 30
            minutesInPreviousPackets += (packetNr - 2) * 13 * 30
        }

        for i in startValue ..< (packet.count - 1) {
            if packet[i] != 0x00 {
                let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 30
                var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                components.hour = minuteOfDay / 60
                components.minute = minuteOfDay % 60
                components.second = 0

                if let sampleDate = calendar.date(from: components) {
                    let sample = HRVSample(timestamp: sampleDate, hrvValue: Int(packet[i]))
                    sessionManager.hrvSamples.append(sample)
                }
            }
        }

        if packetNr == 4 {
            print("HRV sync complete: \(sessionManager.hrvSamples.count) samples")
            sessionManager.hrvHistoryCallback?(sessionManager.hrvSamples)
            syncManager.fetchHistoryTemperature()
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

        sessionManager.spO2Samples.removeAll()

        let length = Int(packet[2]) | (Int(packet[3]) << 8)
        var index = 6
        var daysAgo = -1
        let calendar = Calendar.current

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
                    components.hour = hour
                    components.minute = 0
                    components.second = 0

                    if let hourDate = calendar.date(from: components) {
                        let avgSpO2 = Int(round((spo2Min + spo2Max) / 2.0))
                        let sample = SpO2Sample(timestamp: hourDate, spO2: avgSpO2)
                        sessionManager.spO2Samples.append(sample)
                    }
                }

                if (index - 6) >= length { break }
            }
        }

        print("SpO2 sync complete: \(sessionManager.spO2Samples.count) samples")
        sessionManager.spO2HistoryCallback?(sessionManager.spO2Samples)
    }

    func handleSleepHistory(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        sessionManager.sleepRecords.removeAll()

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

            let daysAgo = Int(packet[index]); index += 1
            let dayBytes = Int(packet[index]); index += 1

            let sleepStart = Int(packet[index]) | (Int(packet[index + 1]) << 8); index += 2
            let sleepEnd = Int(packet[index]) | (Int(packet[index + 1]) << 8); index += 2

            let midnight = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            )

            var sessionStart: Date
            if sleepStart > sleepEnd {
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart - 1440, to: midnight)!
            } else {
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart, to: midnight)!
            }
            let sessionEnd = calendar.date(byAdding: .minute, value: sleepEnd, to: midnight)!

            print("Sleep: \(sessionStart) → \(sessionEnd)")

            var sleepStageTime = sessionStart

            // QUIRK: sleep stage data starts at offset 4 within the day block,
            // pairs of [type, minutes], where type matches SLEEP_TYPE_* constants.
            for _ in stride(from: 4, to: dayBytes, by: 2) {
                guard index + 1 < packet.count else { break }

                let stageTypeByte = packet[index]
                let sleepMinutes = Int(packet[index + 1])
                index += 2

                guard sleepMinutes > 0 else { continue }

                let sleepType: SleepRecord.SleepType
                switch stageTypeByte {
                case RingConstants.SLEEP_TYPE_LIGHT: sleepType = .light // 0x02
                case RingConstants.SLEEP_TYPE_DEEP: sleepType = .deep // 0x03
                case RingConstants.SLEEP_TYPE_REM: sleepType = .rem // 0x04
                case RingConstants.SLEEP_TYPE_AWAKE: sleepType = .awake // 0x05
                default: sleepType = .awake
                }

                let stageEnd = calendar.date(byAdding: .minute, value: sleepMinutes, to: sleepStageTime)!

                if sleepStageTime.addingTimeInterval(TimeInterval(sleepMinutes * 60)) > sessionEnd {
                    print("Sleep stage exceeds session end — data may be corrupt")
                }

                let record = SleepRecord(startTime: sleepStageTime, endTime: stageEnd, sleepType: sleepType)
                sessionManager.sleepRecords.append(record)
                sleepStageTime = stageEnd
            }
        }

        print("Sleep sync complete: \(sessionManager.sleepRecords.count) records")
        sessionManager.sleepHistoryCallback?(sessionManager.sleepRecords)
    }

    func handleTemperatureHistory(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }

        sessionManager.temperatureSamples.removeAll()

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
            index += 1 // QUIRK: skip one unknown byte (always observed as 0x1e)

            let baseDay = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            )

            for hour in 0 ... 23 {
                guard index + 1 < packet.count else { break }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
                components.second = 0

                let temp00 = Float(packet[index]); index += 1
                let temp30 = Float(packet[index]); index += 1

                // QUIRK: raw value encodes °C as (value/10) + 20
                if temp00 > 0 {
                    components.hour = hour
                    components.minute = 0
                    if let t = calendar.date(from: components) {
                        let celsius = Double((temp00 / 10.0) + 20.0)
                        sessionManager.temperatureSamples.append(
                            TemperatureSample(timestamp: t, temperature: celsius)
                        )
                    }
                }

                if temp30 > 0 {
                    components.hour = hour
                    components.minute = 30
                    if let t = calendar.date(from: components) {
                        let celsius = Double((temp30 / 10.0) + 20.0)
                        sessionManager.temperatureSamples.append(
                            TemperatureSample(timestamp: t, temperature: celsius)
                        )
                    }
                }

                if (index - 6) >= length { break }
            }
        }

        print("Temperature sync complete: \(sessionManager.temperatureSamples.count) samples")
        sessionManager.temperatureHistoryCallback?(sessionManager.temperatureSamples)
    }
}
