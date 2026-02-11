//
//  PacketHandler.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

// MARK: - PacketHandlers

/// Handles incoming BLE packets from the smart ring device
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
    
    /// Routes incoming packets to appropriate handlers based on command byte
    func handlePacket(_ packet: [UInt8]) {
        guard packet.count > 0 else { return }
        
        let command = packet[0]
        
        // Debug logging for notification and realtime packets
        if command == RingConstants.CMD_NOTIFICATION ||
           command == RingConstants.CMD_REALTIME_HEART_RATE {
            print("📦 Full packet [0x\(String(format: "%02X", command))]: \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        switch command {
        case RingConstants.CMD_SET_DATE_TIME:
            print("Received set date/time response")
            
        case RingConstants.CMD_BATTERY:
            handleBatteryResponse(packet)
            
        case RingConstants.CMD_PHONE_NAME:
            print("Received phone name response")
            
        case RingConstants.CMD_PREFERENCES:
            print("Received user preferences response")
            
        case RingConstants.CMD_SYNC_HEART_RATE:
            handleHeartRateHistoryPacket(packet)
            
        case RingConstants.CMD_AUTO_HR_PREF:
            handleHeartRateSettingsResponse(packet)
            
        case RingConstants.CMD_GOALS:
            handleGoalsResponse(packet)
            
        case RingConstants.CMD_AUTO_SPO2_PREF:
            handleSpO2SettingsResponse(packet)
            
        case RingConstants.CMD_PACKET_SIZE:
            if packet.count > 1 {
                print("Received packet size indicator: \(packet[1]) bytes")
            }
            
        case RingConstants.CMD_AUTO_STRESS_PREF:
            handleStressSettingsResponse(packet)
            
        case RingConstants.CMD_AUTO_HRV_PREF:
            handleHRVSettingsResponse(packet)
            
        case RingConstants.CMD_AUTO_TEMP_PREF:
            if packet.count > 1 && packet[1] == 0x03 {
                handleTemperatureSettingsResponse(packet)
            }
            
        case RingConstants.CMD_SYNC_STRESS:
            handleStressHistoryPacket(packet)
            
        case RingConstants.CMD_SYNC_ACTIVITY:
            handleActivityHistoryPacket(packet)
            
        case RingConstants.CMD_SYNC_HRV:
            handleHRVHistoryPacket(packet)
            
        case RingConstants.CMD_FIND_DEVICE:
            print("Received find device response")
            
        case RingConstants.CMD_MANUAL_HEART_RATE:
            handleManualHeartRateResponse(packet)
            
        case RingConstants.CMD_REALTIME_HEART_RATE:
            handleRealtimeHeartRateAcknowledgment(packet)
            
        case RingConstants.CMD_NOTIFICATION:
            handleNotificationPacket(packet)
            
        case RingConstants.CMD_BIG_DATA_V2:
            handleBigDataPacket(packet)
            
        default:
            print("Unrecognized packet command: 0x\(String(format: "%02X", command))")
        }
    }
    
    // MARK: - Basic Response Handlers
    
    /// Handles battery status response packets
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
    
    /// Handles manual heart rate measurement response
    private func handleManualHeartRateResponse(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }
        
        let errorCode = Int(packet[2])
        let hrResponse = Int(packet[3])
        
        switch errorCode {
        case 0:
            print("Manual HR: \(hrResponse) bpm")
            sessionManager.realtimeHeartRate = hrResponse
            
            if hrResponse > 0 {
                let sample = HeartRateSample(timestamp: Date(), heartRate: hrResponse)
                sessionManager.heartRateSamples.append(sample)
            }
            
        case 1:
            print("HR error: ring worn incorrectly")
        case 2:
            print("HR error: temporary error/missing data")
        default:
            print("HR error code: \(errorCode)")
        }
    }
    
    /// Handles realtime heart rate monitoring packets
    private func handleRealtimeHeartRateAcknowledgment(_ packet: [UInt8]) {
        guard packet.count >= 2, let sessionManager = sessionManager else { return }
        
        let sequenceNumber = packet[1]
        
        // Check if this is just an echo/acknowledgment (all zeros after sequence)
        if packet.count >= 6 && packet[2] == 0x00 && packet[3] == 0x00 {
            print("Realtime HR monitoring acknowledged (sequence: \(sequenceNumber))")
            print("Waiting for actual HR data...")
            return
        }
        
        // Packet contains actual heart rate data
        // Structure: [0]=0x69, [1]=sequence, [2]=unknown, [3]=HR value, [4]=0x6A, [5]=HR/quality
        if packet.count >= 4 {
            let heartRate = Int(packet[3])
            
            // Validate heart rate is in reasonable physiological range
            if heartRate >= 30 && heartRate <= 220 {
                print("✅ Realtime HR: \(heartRate) bpm (raw: 0x\(String(format: "%02X", packet[3])))")
                
                sessionManager.realtimeHeartRate = heartRate
                
                let sample = HeartRateSample(timestamp: Date(), heartRate: heartRate)
                sessionManager.heartRateSamples.append(sample)
                
                // Notify listeners
                NotificationCenter.default.post(
                    name: NSNotification.Name("RealtimeHeartRateUpdated"),
                    object: nil,
                    userInfo: ["heartRate": heartRate]
                )
            } else if heartRate == 0 {
                print("⚠️ No HR reading yet (ring may still be measuring)")
            } else {
                print("⚠️ Invalid HR value: \(heartRate) bpm (out of range 30-220)")
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    /// Routes notification packets to specific handlers
    private func handleNotificationPacket(_ packet: [UInt8]) {
        guard packet.count > 1 else { return }
        
        let notificationType = packet[1]
        
        switch notificationType {
        case RingConstants.NOTIFICATION_NEW_HR_DATA:
            print("New HR data available (stored history)")
            
        case RingConstants.NOTIFICATION_NEW_SPO2_DATA:
            print("New SpO2 data available")
            
        case RingConstants.NOTIFICATION_NEW_STEPS_DATA:
            print("New steps data available")
            
        case RingConstants.NOTIFICATION_BATTERY_LEVEL:
            if packet.count >= 4, let sessionManager = sessionManager {
                let level = Int(packet[2])
                let charging = packet[3] == 1
                print("Battery notification: \(level)%, charging: \(charging)")
                
                let batteryInfo = BatteryInfo(batteryLevel: level, charging: charging)
                sessionManager.currentBatteryInfo = batteryInfo
            }
            
        case RingConstants.NOTIFICATION_LIVE_ACTIVITY:
            handleLiveActivityPacket(packet)
            
        default:
            print("Unrecognized notification: 0x\(String(format: "%02X", notificationType))")
            print("Full notification packet: \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
    
    /// Handles live activity data (realtime sensor readings)
    private func handleLiveActivityPacket(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else {
            print("Live activity packet too short or no session manager")
            return
        }
        
        // Packet structure: [0]=0x17, [1]=0x05, [2]=data type, [3+]=sensor data
        let dataType = packet[2]
        
        switch dataType {
        case 0x01: // Heart rate
            if packet.count >= 4 {
                let heartRate = Int(packet[3])
                
                if heartRate >= 30 && heartRate <= 220 {
                    print("✅ Realtime HR: \(heartRate) bpm")
                    
                    sessionManager.realtimeHeartRate = heartRate
                    
                    let sample = HeartRateSample(timestamp: Date(), heartRate: heartRate)
                    sessionManager.heartRateSamples.append(sample)
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RealtimeHeartRateUpdated"),
                        object: nil,
                        userInfo: ["heartRate": heartRate]
                    )
                } else if heartRate == 0 {
                    print("⚠️ No HR reading yet (ring may still be measuring)")
                } else {
                    print("⚠️ Invalid HR value: \(heartRate) bpm (out of range 30-220)")
                }
            }
            
        case 0x03: // Calories
            if packet.count >= 6 {
                let calories = Int(packet[3]) | (Int(packet[4]) << 8)
                print("✅ Realtime calories: \(calories)")
            }
            
        default:
            print("❓ Unknown live activity data type: 0x\(String(format: "%02X", dataType))")
            print("Full packet: \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
    
    // MARK: - Settings Response Handlers
    
    private func handleHeartRateSettingsResponse(_ packet: [UInt8]) {
        guard packet.count >= 4 else { return }
        
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
        let calories = Int(packet[5]) | (Int(packet[6]) << 8) | (Int(packet[7]) << 16)
        let distance = Int(packet[8]) | (Int(packet[9]) << 8) | (Int(packet[10]) << 16)
        let sport = Int(packet[11]) | (Int(packet[12]) << 8)
        let sleep = Int(packet[13]) | (Int(packet[14]) << 8)
        
        print("Goals: \(steps) steps, \(calories) cal, \(distance)m, \(sport)min sport, \(sleep)min sleep")
    }
}

// MARK: - Historical Data Handlers

extension PacketHandlers {
    
    /// Processes heart rate history sync packets
    func handleHeartRateHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }
        
        let packetNr = Int(packet[1])
        
        // Empty history indicator
        if packetNr == 0xff {
            print("Empty HR history")
            return
        }
        
        // First packet contains total count
        if packetNr == 0 {
            syncManager.packetsTotalNr = Int(packet[2])
            print("HR packet 0/\(syncManager.packetsTotalNr)")
            syncManager.currentHRPacketNr = 0
            sessionManager.heartRateSamples.removeAll()
        } else {
            print("HR packet \(packetNr)/\(syncManager.packetsTotalNr)")
            
            guard let syncDay = syncManager.syncingDay else { return }
            let calendar = Calendar.current
            
            // Determine starting byte and calculate time offset
            let startValue = packetNr == 1 ? 6 : 2
            var minutesInPreviousPackets = 0
            
            if packetNr > 1 {
                minutesInPreviousPackets = 9 * 5 // First packet has 9 samples
                minutesInPreviousPackets += (packetNr - 2) * 13 * 5 // Subsequent packets have 13 samples
            }
            
            // Parse heart rate samples (5-minute intervals)
            for i in startValue..<(packet.count - 1) {
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
            
            // Sync complete
            if packetNr == syncManager.packetsTotalNr - 1 {
                print("HR sync complete: \(sessionManager.heartRateSamples.count) samples")
                sessionManager.heartRateHistoryCallback?(sessionManager.heartRateSamples)
            }
        }
    }
    
    /// Processes stress history sync packets
    func handleStressHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }
        
        let packetNr = Int(packet[1])
        
        if packetNr == 0xff {
            print("Empty stress history")
            syncManager.fetchHistorySpO2()
            return
        }
        
        if packetNr > 0 {
            print("Stress packet \(packetNr)")
            
            let calendar = Calendar.current
            let sampleCal = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: Date()))!
            
            let startValue = packetNr == 1 ? 3 : 2
            var minutesInPreviousPackets = 0
            
            if packetNr > 1 {
                minutesInPreviousPackets = 12 * 30
                minutesInPreviousPackets += (packetNr - 2) * 13 * 30
            }
            
            // Parse stress samples (30-minute intervals)
            for i in startValue..<(packet.count - 1) {
                if packet[i] != 0x00 {
                    let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 30
                    
                    var components = calendar.dateComponents([.year, .month, .day], from: sampleCal)
                    components.hour = minuteOfDay / 60
                    components.minute = minuteOfDay % 60
                    components.second = 0
                    
                    if let sampleDate = calendar.date(from: components) {
                        let sample = StressSample(timestamp: sampleDate, stressLevel: Int(packet[i]))
                        sessionManager.stressSamples.append(sample)
                    }
                }
            }
            
            if packetNr == 4 {
                print("Stress sync complete: \(sessionManager.stressSamples.count) samples")
                sessionManager.stressHistoryCallback?(sessionManager.stressSamples)
            }
        }
        
        syncManager.fetchHistorySpO2()
    }
    
    /// Processes activity history sync packets
    func handleActivityHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }
        
        let packetType = Int(packet[1])
        
        if packetType == 0xff {
            print("Empty activity history")
            return
        }
        
        if packetType == 0xf0 {
            return
        }
        
        let calendar = Calendar.current
        
        // Parse date from BCD format
        let yearHex = String(format: "%02x", packet[1])
        let monthHex = String(format: "%02x", packet[2])
        let dayHex = String(format: "%02x", packet[3])
        
        if let year = Int(yearHex), let month = Int(monthHex), let day = Int(dayHex) {
            var components = DateComponents()
            components.year = 2000 + year
            components.month = month
            components.day = day
            components.hour = Int(packet[4]) / 4
            components.minute = 0
            components.second = 0
            
            if let date = calendar.date(from: components) {
                let calories = Int(packet[7]) | (Int(packet[8]) << 8)
                let steps = Int(packet[9]) | (Int(packet[10]) << 8)
                let distance = Int(packet[11]) | (Int(packet[12]) << 8)
                
                print("Activity: \(date) - \(steps) steps, \(calories) cal, \(distance)m")
                
                let sample = ActivitySample(timestamp: date, steps: steps, distance: distance, calories: calories)
                sessionManager.activitySamples.append(sample)
                
                let currentPacket = Int(packet[5])
                let totalPackets = Int(packet[6])
                
                if currentPacket == totalPackets - 1 {
                    print("Activity sync complete: \(sessionManager.activitySamples.count) samples")
                    sessionManager.activityHistoryCallback?(sessionManager.activitySamples)
                    
                    if syncManager.daysAgo < 7 {
                        syncManager.daysAgo += 1
                        syncManager.fetchHistoryActivity()
                    } else {
                        syncManager.daysAgo = 0
                        syncManager.fetchHistoryHeartRate()
                    }
                }
            }
        }
    }
    
    /// Processes HRV history sync packets
    func handleHRVHistoryPacket(_ packet: [UInt8]) {
        guard packet.count > 1,
              let sessionManager = sessionManager,
              let syncManager = syncManager else { return }
        
        let packetNr = Int(packet[1])
        
        if packetNr == 0xff {
            print("Empty HRV history")
            syncManager.fetchHistoryTemperature()
            return
        }
        
        if packetNr > 0 {
            print("HRV packet \(packetNr)")
            
            let calendar = Calendar.current
            var sampleCal = Date()
            
            if syncManager.daysAgo != 0 {
                sampleCal = calendar.date(byAdding: .day, value: -syncManager.daysAgo, to: Date())!
                sampleCal = calendar.startOfDay(for: sampleCal)
            }
            
            let startValue = packetNr == 1 ? 3 : 2
            var minutesInPreviousPackets = 0
            
            if packetNr > 1 {
                minutesInPreviousPackets = 12 * 30
                minutesInPreviousPackets += (packetNr - 2) * 13 * 30
            }
            
            // Parse HRV samples (30-minute intervals)
            for i in startValue..<(packet.count - 1) {
                if packet[i] != 0x00 {
                    let minuteOfDay = minutesInPreviousPackets + (i - startValue) * 30
                    
                    var components = calendar.dateComponents([.year, .month, .day], from: sampleCal)
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
            }
        }
        
        syncManager.fetchHistoryTemperature()
    }
}

// MARK: - Big Data Handlers

extension PacketHandlers {
    
    /// Processes large data packets (temperature, sleep, SpO2)
    func handleBigDataPacket(_ packet: [UInt8]) {
        guard packet.count >= 4, let syncManager = syncManager else { return }
        
        let packetLength = Int(packet[2]) | (Int(packet[3]) << 8)
        
        // Check if packet is incomplete and needs buffering
        if packet.count < packetLength + 6 {
            print("Big data incomplete, buffering...")
            syncManager.bigDataPacketSize = packetLength
            syncManager.bigDataPacket = Data(packet)
            return
        }
        
        var completePacket = packet
        
        // Combine with buffered data if available
        if let bufferedData = syncManager.bigDataPacket {
            var combined = Data(bufferedData)
            combined.append(Data(packet))
            completePacket = [UInt8](combined)
            syncManager.bigDataPacket = nil
            print("Big data complete")
        }
        
        guard completePacket.count > 1 else { return }
        
        let dataType = completePacket[1]
        
        switch dataType {
        case RingConstants.BIG_DATA_TYPE_TEMPERATURE:
            handleTemperatureHistory(completePacket)
            syncManager.fetchRecordedDataFinished()
            
        case RingConstants.BIG_DATA_TYPE_SLEEP:
            handleSleepHistory(completePacket)
            syncManager.daysAgo = 0
            syncManager.fetchHistoryHRV()
            
        case RingConstants.BIG_DATA_TYPE_SPO2:
            handleSpO2History(completePacket)
            syncManager.fetchHistorySleep()
            
        default:
            print("Unrecognized big data type: 0x\(String(format: "%02X", dataType))")
        }
    }
    
    /// Parses SpO2 historical data
    func handleSpO2History(_ packet: [UInt8]) {
        guard packet.count >= 4, let sessionManager = sessionManager else { return }
        
        sessionManager.spO2Samples.removeAll()
        
        let length = Int(packet[2]) | (Int(packet[3]) << 8)
        var index = 6
        var daysAgo = -1
        
        let calendar = Calendar.current
        
        while daysAgo != 0 && index - 6 < length {
            daysAgo = Int(packet[index])
            
            var syncingDay = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            syncingDay = calendar.startOfDay(for: syncingDay)
            
            index += 1
            
            // Parse hourly min/max SpO2 values
            for hour in 0...23 {
                guard index + 1 < packet.count else { break }
                
                var components = calendar.dateComponents([.year, .month, .day], from: syncingDay)
                components.hour = hour
                components.minute = 0
                
                let spo2Min = Float(packet[index])
                index += 1
                let spo2Max = Float(packet[index])
                index += 1
                
                if spo2Min > 0 && spo2Max > 0, let hourDate = calendar.date(from: components) {
                    let avgSpO2 = Int(round((spo2Min + spo2Max) / 2.0))
                    let sample = SpO2Sample(timestamp: hourDate, spO2: avgSpO2)
                    sessionManager.spO2Samples.append(sample)
                }
                
                if index - 6 >= length { break }
            }
        }
        
        print("SpO2 sync complete: \(sessionManager.spO2Samples.count) samples")
        sessionManager.spO2HistoryCallback?(sessionManager.spO2Samples)
    }
    
    /// Parses sleep session historical data
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
        
        for _ in 1...daysInPacket {
            guard index < packet.count else { break }
            
            let daysAgo = Int(packet[index])
            index += 1
            
            let dayBytes = Int(packet[index])
            index += 1
            
            let sleepStart = Int(packet[index]) | (Int(packet[index + 1]) << 8)
            index += 2
            
            let sleepEnd = Int(packet[index]) | (Int(packet[index + 1]) << 8)
            index += 2
            
            // Calculate session start time (handle overnight sessions)
            var sessionStart = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            sessionStart = calendar.startOfDay(for: sessionStart)
            
            if sleepStart > sleepEnd {
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart - 1440, to: sessionStart)!
            } else {
                sessionStart = calendar.date(byAdding: .minute, value: sleepStart, to: sessionStart)!
            }
            
            var sessionEnd = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            sessionEnd = calendar.startOfDay(for: sessionEnd)
            sessionEnd = calendar.date(byAdding: .minute, value: sleepEnd, to: sessionEnd)!
            
            print("Sleep: \(sessionStart) to \(sessionEnd)")
            
            var sleepStageTime = sessionStart
            
            // Parse sleep stages
            for _ in stride(from: 4, to: dayBytes, by: 2) {
                guard index + 1 < packet.count else { break }
                
                let stageType = packet[index]
                let sleepMinutes = Int(packet[index + 1])
                
                if sleepMinutes > 0 {
                    let sleepType: SleepRecord.SleepType
                    switch stageType {
                    case 0x00: sleepType = .awake
                    case 0x01: sleepType = .light
                    case 0x02: sleepType = .deep
                    case 0x03: sleepType = .rem
                    default: sleepType = .awake
                    }
                    
                    let stageEnd = calendar.date(byAdding: .minute, value: sleepMinutes, to: sleepStageTime)!
                    
                    let record = SleepRecord(startTime: sleepStageTime, endTime: stageEnd, sleepType: sleepType)
                    sessionManager.sleepRecords.append(record)
                    
                    sleepStageTime = stageEnd
                }
                
                index += 2
            }
        }
        
        print("Sleep sync complete: \(sessionManager.sleepRecords.count) records")
        sessionManager.sleepHistoryCallback?(sessionManager.sleepRecords)
    }
    
    /// Parses temperature historical data
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
        
        while daysAgo != 0 && index - 6 < length {
            daysAgo = Int(packet[index])
            
            var syncingDay = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            syncingDay = calendar.startOfDay(for: syncingDay)
            
            index += 1
            index += 1 // Skip unknown byte
            
            // Parse temperature readings (two per hour: 0 and 30 minutes)
            for hour in 0...23 {
                guard index + 1 < packet.count else { break }
                
                var components = calendar.dateComponents([.year, .month, .day], from: syncingDay)
                components.hour = hour
                components.minute = 0
                
                let temp00 = Float(packet[index])
                index += 1
                
                let temp30 = Float(packet[index])
                index += 1
                
                // Convert and store temperature at hour mark
                if temp00 > 0, let hourDate = calendar.date(from: components) {
                    let temperature = (temp00 / 10.0) + 20.0
                    let sample = TemperatureSample(timestamp: hourDate, temperature: Double(temperature))
                    sessionManager.temperatureSamples.append(sample)
                }
                
                // Convert and store temperature at half-hour mark
                components.minute = 30
                if temp30 > 0, let halfHourDate = calendar.date(from: components) {
                    let temperature = (temp30 / 10.0) + 20.0
                    let sample = TemperatureSample(timestamp: halfHourDate, temperature: Double(temperature))
                    sessionManager.temperatureSamples.append(sample)
                }
                
                if index - 6 >= length { break }
            }
        }
        
        print("Temperature sync complete: \(sessionManager.temperatureSamples.count) samples")
        sessionManager.temperatureHistoryCallback?(sessionManager.temperatureSamples)
    }
}
