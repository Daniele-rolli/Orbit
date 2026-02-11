//
//  RealtimeManager.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

class RealtimeManager {
    
    weak var sessionManager: RingSessionManager?
    
    private var realtimeHrmPacketCount: Int = 0
    private var isRealtimeHrmActive = false
    private var isRealtimeStepsActive = false
    private var liveActivityTimer: Timer?
    
    // Live activity tracking state
    private var lastTotalSteps: Int = 0
    private var lastTotalCalories: Int = 0
    private var lastTotalDistance: Int = 0
    private var bufferedSteps: Int = 0
    private var bufferedCalories: Int = 0
    private var bufferedDistance: Int = 0
    
    init(sessionManager: RingSessionManager) {
        self.sessionManager = sessionManager
    }
    
    deinit {
        stopRealtimeSteps()
        liveActivityTimer?.invalidate()
    }
    
    private func sendCommand(_ command: UInt8, subData: [UInt8] = []) {
        sessionManager?.bluetoothManager?.sendCommand(command, subData: subData)
    }
    
    // MARK: - Realtime Heart Rate
    
    func startRealtimeHeartRate() {
        isRealtimeHrmActive = true
        realtimeHrmPacketCount = 0
        sendCommand(RingConstants.CMD_REALTIME_HEART_RATE, subData: [0x01])
    }
    
    func stopRealtimeHeartRate() {
        isRealtimeHrmActive = false
        sendCommand(RingConstants.CMD_REALTIME_HEART_RATE, subData: [0x02])
    }
    
    func continueRealtimeHeartRate() {
        guard isRealtimeHrmActive else { return }
        sendCommand(RingConstants.CMD_REALTIME_HEART_RATE, subData: [0x03])
    }
    
    func handleRealtimeHeartRatePacket(_ packet: [UInt8]) {
        guard
            let sessionManager = sessionManager,
            packet.count >= 2
        else {
            print("HR packet invalid length: \(packet)")
            return
        }

        // Raw packet logging (critical)
        let hex = packet.map { String(format: "%02X", $0) }.joined(separator: " ")
        let hrByte = packet[1]
        let heartRate = Int(hrByte)

        print("HR raw packet: [\(hex)] → HR byte: \(hrByte) (\(heartRate) bpm)")

        // Ignore invalid values
        guard heartRate > 0 && heartRate < 240 else {
            print("HR value out of range: \(heartRate)")
            return
        }

        // Update realtime value only if it actually changed
        if sessionManager.realtimeHeartRate != heartRate {
            print("Realtime HR updated: \(sessionManager.realtimeHeartRate ?? -1) → \(heartRate)")
            sessionManager.realtimeHeartRate = heartRate

            // ⚠️ Do NOT oversample storage with realtime noise
            // Only append if different from last stored value
            if sessionManager.heartRateSamples.last?.heartRate != heartRate {
                let sample = HeartRateSample(
                    timestamp: Date(),
                    heartRate: heartRate
                )
                sessionManager.heartRateSamples.append(sample)
            }
        } else {
            print("Realtime HR unchanged: \(heartRate)")
        }

        // Packet pacing
        if isRealtimeHrmActive {
            realtimeHrmPacketCount += 1
            print("HR packet count: \(realtimeHrmPacketCount)")

            if realtimeHrmPacketCount % 30 == 0 {
                print("Requesting HR continuation")
                continueRealtimeHeartRate()
            }
        }
    }

    // MARK: - Realtime Steps
    
    func startRealtimeSteps() {
        guard !isRealtimeStepsActive else { return }
        isRealtimeStepsActive = true
        
        guard let sessionManager = sessionManager else { return }
        
        // Reset tracking values
        sessionManager.liveActivity = LiveActivity(steps: 0, distance: 0, calories: 0)
        lastTotalSteps = 0
        lastTotalCalories = 0
        lastTotalDistance = 0
        bufferedSteps = 0
        bufferedCalories = 0
        bufferedDistance = 0
        
        // Start periodic updates
        liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.processLiveActivityBuffer()
        }
        
        print("Started realtime steps tracking")
    }
    
    func stopRealtimeSteps() {
        guard isRealtimeStepsActive else { return }
        isRealtimeStepsActive = false
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
    }
    
    func handleLiveActivityPacket(_ packet: [UInt8]) {
        guard let sessionManager = sessionManager, packet.count >= 11 else { return }
        
        let steps = Int(packet[4]) | (Int(packet[3]) << 8) | (Int(packet[2]) << 16)
        let calories = (Int(packet[7]) | (Int(packet[6]) << 8) | (Int(packet[5]) << 16)) / 10
        let distance = Int(packet[10]) | (Int(packet[9]) << 8) | (Int(packet[8]) << 16)
        
        print("Received live activity: \(steps) steps, \(calories) cal, \(distance)m")
        
        // Calculate deltas
        if lastTotalSteps == 0 { lastTotalSteps = steps }
        if lastTotalCalories == 0 { lastTotalCalories = calories }
        if lastTotalDistance == 0 { lastTotalDistance = distance }
        
        let deltaSteps = steps - lastTotalSteps
        let deltaCalories = calories - lastTotalCalories
        let deltaDistance = distance - lastTotalDistance
        
        lastTotalSteps = steps
        lastTotalCalories = calories
        lastTotalDistance = distance
        
        // Buffer the deltas
        bufferedSteps += deltaSteps
        bufferedCalories += deltaCalories
        bufferedDistance += deltaDistance
        
        // Update live activity (cumulative totals)
        sessionManager.liveActivity = LiveActivity(steps: steps, distance: distance, calories: calories)
    }
    
    private func processLiveActivityBuffer() {
        guard let sessionManager = sessionManager else { return }
        
        if bufferedSteps > 0 || bufferedCalories > 0 || bufferedDistance > 0 {
            let sample = ActivitySample(
                timestamp: Date(),
                steps: bufferedSteps,
                distance: bufferedDistance,
                calories: bufferedCalories
            )
            
            sessionManager.activitySamples.append(sample)
            
            print("Buffered activity: \(bufferedSteps) steps, \(bufferedCalories) cal, \(bufferedDistance)m")
            
            // Reset buffer
            bufferedSteps = 0
            bufferedCalories = 0
            bufferedDistance = 0
        }
    }
}
