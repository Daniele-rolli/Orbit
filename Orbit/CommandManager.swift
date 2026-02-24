//
//  CommandManager.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation

class CommandManager {
    weak var sessionManager: RingSessionManager?

    init(sessionManager: RingSessionManager) {
        self.sessionManager = sessionManager
    }

    private func sendCommand(_ command: UInt8, subData: [UInt8] = []) {
        sessionManager?.bluetoothManager?.sendCommand(command, subData: subData)
    }

    // MARK: - Basic Commands

    func setPhoneName(name: String = "GB") {
        let nameBytes = Array(name.utf8).prefix(13)
        let subData: [UInt8] = [0x02, 0x0A] + nameBytes
        sendCommand(RingConstants.CMD_PHONE_NAME, subData: subData)
    }

    func setDateTime() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)

        // Ring expects BCD encoding (like Gadgetbridge):
        // each decimal value is encoded by parsing its digit string as hex.
        // e.g. hour=16 → "16" parsed as hex → 0x16, NOT raw 0x10.
        func bcd(_ value: Int) -> UInt8 { UInt8(strtoul(String(value), nil, 16)) }

        let subData: [UInt8] = [
            bcd(components.year! % 2000),
            bcd(components.month!),
            bcd(components.day!),
            bcd(components.hour!),
            bcd(components.minute!),
            bcd(components.second!),
        ]

        sendCommand(RingConstants.CMD_SET_DATE_TIME, subData: subData)
        print("Set date/time: \(now) → BCD bytes: \(subData.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }

    func requestBatteryInfo() {
        sendCommand(RingConstants.CMD_BATTERY)
    }

    func findDevice() {
        sendCommand(RingConstants.CMD_FIND_DEVICE, subData: [0x55, 0xAA])
    }

    func powerOff() {
        sendCommand(RingConstants.CMD_POWER_OFF, subData: [0x01])
    }

    func factoryReset() {
        sendCommand(RingConstants.CMD_FACTORY_RESET, subData: [0x66, 0x66])
    }

    // MARK: - User Preferences

    func setUserPreferences(_ prefs: UserPreferences) {
        let subData: [UInt8] = [
            RingConstants.PREF_WRITE,
            prefs.timeFormat.rawValue,
            prefs.measurementSystem.rawValue,
            prefs.gender.rawValue,
            UInt8(prefs.age),
            UInt8(prefs.heightCm),
            UInt8(prefs.weightKg),
            UInt8(prefs.systolicBP),
            UInt8(prefs.diastolicBP),
            UInt8(prefs.hrWarningThreshold),
        ]

        sendCommand(RingConstants.CMD_PREFERENCES, subData: subData)
    }

    func requestUserPreferences() {
        sendCommand(RingConstants.CMD_PREFERENCES, subData: [RingConstants.PREF_READ])
    }

    // MARK: - Display Settings
    func setDisplaySettings(_ settings: DisplaySettings) {
        let subData: [UInt8] = [
            0x04,
            settings.enabled ? 0x01 : 0x02,
            settings.wearLocation.rawValue,
            UInt8(settings.brightness + 1),
            0x05,
            settings.allDay ? 0x02 : 0x01,
            UInt8(settings.startHour),
            UInt8(settings.startMinute),
            UInt8(settings.endHour),
            UInt8(settings.endMinute),
        ]

        sendCommand(RingConstants.CMD_DISPLAY_PREF, subData: subData)
    }

    // MARK: - Goals

    func requestGoals() {
        sendCommand(RingConstants.CMD_GOALS, subData: [RingConstants.PREF_READ])
    }

    func setGoals(_: Goals) {
        sendCommand(RingConstants.CMD_GOALS, subData: [RingConstants.PREF_WRITE])
    }

    // MARK: - Heart Rate Settings

    func setHeartRateMeasurementInterval(minutes: Int) {
        // Only allow intervals from the known valid set: 0, 5, 10, 15, 30, 45, 60
        let validIntervals = RingConstants.heartRateMeasurementIntervals
        let intervalMins = validIntervals.contains(minutes) ? minutes : 0
        let enabled: UInt8 = intervalMins > 0 ? 0x01 : 0x00

        let subData: [UInt8] = [
            RingConstants.PREF_WRITE,
            enabled,
            UInt8(intervalMins),
        ]

        sendCommand(RingConstants.CMD_AUTO_HR_PREF, subData: subData)
    }

    func requestHeartRateSettings() {
        sendCommand(RingConstants.CMD_AUTO_HR_PREF, subData: [RingConstants.PREF_READ])
    }

    // MARK: - SpO2 Settings

    func setSpO2AllDayMonitoring(enabled: Bool) {
        let subData: [UInt8] = [
            RingConstants.PREF_WRITE,
            enabled ? 0x01 : 0x00,
        ]
        sendCommand(RingConstants.CMD_AUTO_SPO2_PREF, subData: subData)
    }

    func requestSpO2Settings() {
        sendCommand(RingConstants.CMD_AUTO_SPO2_PREF, subData: [RingConstants.PREF_READ])
    }

    // MARK: - Stress Settings

    func setStressMonitoring(enabled: Bool) {
        let subData: [UInt8] = [
            RingConstants.PREF_WRITE,
            enabled ? 0x01 : 0x00,
        ]
        sendCommand(RingConstants.CMD_AUTO_STRESS_PREF, subData: subData)
    }

    func requestStressSettings() {
        sendCommand(RingConstants.CMD_AUTO_STRESS_PREF, subData: [RingConstants.PREF_READ])
    }

    // MARK: - HRV Settings

    func setHRVAllDayMonitoring(enabled: Bool) {
        let subData: [UInt8] = [
            RingConstants.PREF_WRITE,
            enabled ? 0x01 : 0x00,
        ]
        sendCommand(RingConstants.CMD_AUTO_HRV_PREF, subData: subData)
    }

    func requestHRVSettings() {
        sendCommand(RingConstants.CMD_AUTO_HRV_PREF, subData: [RingConstants.PREF_READ])
    }

    // MARK: - Temperature Settings

    // NOTE: Temperature commands should only be sent to rings that support it.
    // Gate on sessionManager.ringModel.supportsTemperature before calling.

    func setTemperatureAllDayMonitoring(enabled: Bool) {
        let subData: [UInt8] = [
            0x03,
            RingConstants.PREF_WRITE,
            enabled ? 0x01 : 0x00,
        ]
        sendCommand(RingConstants.CMD_AUTO_TEMP_PREF, subData: subData)
    }

    func requestTemperatureSettings() {
        sendCommand(RingConstants.CMD_AUTO_TEMP_PREF, subData: [0x03, RingConstants.PREF_READ])
    }

    // MARK: - Manual Measurements

    func triggerManualHeartRate() {
        sendCommand(RingConstants.CMD_MANUAL_HEART_RATE, subData: [0x01])
    }

    // MARK: - Request All Settings

    func requestSettingsFromRing() {
        requestHeartRateSettings()
        requestStressSettings()
        requestSpO2Settings()
        requestHRVSettings()
        requestGoals()

        // Only request temperature settings on supported devices
        if let model = sessionManager?.ringModel, model.supportsTemperature {
            requestTemperatureSettings()
        }
    }
}
