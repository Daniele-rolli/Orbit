//
//  RingSessionManager.swift
//  Orbit
//
//  Main coordinator for Ring communication
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI

// MARK: - RingSessionManager

@Observable
class RingSessionManager: NSObject {
    
    // MARK: - Connection State
    var peripheralConnected = false
    var peripheralReady = false
    var pickerDismissed = true
    
    
    // MARK: - Device
    var deviceInfo = DeviceInfo()
    var currentRing: ASAccessory?
    var peripheral: CBPeripheral?
    
    // MARK: - Data Storage
    var heartRateSamples: [HeartRateSample] = []
    var stressSamples: [StressSample] = []
    var spO2Samples: [SpO2Sample] = []
    var activitySamples: [ActivitySample] = []
    var hrvSamples: [HRVSample] = []
    var temperatureSamples: [TemperatureSample] = []
    var sleepRecords: [SleepRecord] = []
    
    // MARK: - Live Data
    var currentBatteryInfo: BatteryInfo?
    var liveActivity = LiveActivity(steps: 0, distance: 0, calories: 0)
    var realtimeHeartRate: Int?
    var realtimeSpO2: Int?
    var realtimeStress: Int?
    var realtimeTemperature: Double?
    
    // MARK: - Managers
    private var session = ASAccessorySession()
    private var manager: CBCentralManager?
    
    var bluetoothManager: BluetoothManager!
    var commandManager: CommandManager!
    var syncManager: SyncManager!
    var realtimeManager: RealtimeManager!
    var storageManager: StorageManager!
    var healthKitManager: HealthKitManager!
    
    // MARK: - Callbacks
    var batteryStatusCallback: ((BatteryInfo) -> Void)?
    var deviceInfoCallback: ((DeviceInfo) -> Void)?
    var heartRateHistoryCallback: (([HeartRateSample]) -> Void)?
    var stressHistoryCallback: (([StressSample]) -> Void)?
    var spO2HistoryCallback: (([SpO2Sample]) -> Void)?
    var activityHistoryCallback: (([ActivitySample]) -> Void)?
    var hrvHistoryCallback: (([HRVSample]) -> Void)?
    var temperatureHistoryCallback: (([TemperatureSample]) -> Void)?
    var sleepHistoryCallback: (([SleepRecord]) -> Void)?
    var syncCompletionCallback: (() -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Initialize managers
        bluetoothManager = BluetoothManager(sessionManager: self)
        commandManager = CommandManager(sessionManager: self)
        syncManager = SyncManager(sessionManager: self)
        realtimeManager = RealtimeManager(sessionManager: self)
        storageManager = StorageManager()
        healthKitManager = HealthKitManager()
        
        // Set up session
        session.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent)
        
        // Load data on startup
        Task {
            try? await loadDataFromEncryptedStorage()
        }
    }
    
    deinit {
        realtimeManager.stopRealtimeSteps()
    }
    
    // MARK: - Session Management
    
    func presentPicker() {
        session.showPicker(for: [RingConstants.pickerDisplayItem]) { error in
            if let error {
                print("Failed to show picker: \(error.localizedDescription)")
            }
        }
    }
    
    func removeRing() {
        guard let currentRing else { return }
        
        if peripheralConnected {
            disconnect()
        }
        
        session.removeAccessory(currentRing) { _ in
            self.currentRing = nil
            self.manager = nil
        }
    }
    
    func connect() {
        bluetoothManager.connect()
    }
    
    func disconnect() {
        bluetoothManager.disconnect()
    }
    
    private func saveRing(ring: ASAccessory) {
        currentRing = ring
        
        if manager == nil {
            manager = CBCentralManager(delegate: bluetoothManager, queue: nil)
            bluetoothManager.centralManager = manager
        }
    }
    
    private func handleSessionEvent(event: ASAccessoryEvent) {
        print("Session event: \(event.eventType)")
        
        switch event.eventType {
        case .accessoryAdded, .accessoryChanged:
            guard let ring = event.accessory else { return }
            saveRing(ring: ring)
            
        case .activated:
            guard let ring = session.accessories.first else { return }
            saveRing(ring: ring)
            
        case .accessoryRemoved:
            currentRing = nil
            manager = nil
            
        case .pickerDidPresent:
            pickerDismissed = false
            
        case .pickerDidDismiss:
            pickerDismissed = true
            
        default:
            print("Received event type \(event.eventType)")
        }
    }
    
    // MARK: - Post Connection
    
    func postConnectInitialization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.commandManager.setPhoneName()
            self.commandManager.setDateTime()
            self.commandManager.requestBatteryInfo()
            self.commandManager.requestSettingsFromRing()
        }
    }
    
    // MARK: - Command Manager API
    
    func setPhoneName(name: String = "GB") {
        commandManager.setPhoneName(name: name)
    }
    
    func setDateTime() {
        commandManager.setDateTime()
    }
    
    func requestBatteryInfo(completion: ((BatteryInfo) -> Void)? = nil) {
        self.batteryStatusCallback = completion
        commandManager.requestBatteryInfo()
    }
    
    func findDevice() {
        commandManager.findDevice()
    }
    
    func powerOff() {
        commandManager.powerOff()
    }
    
    func factoryReset() {
        commandManager.factoryReset()
    }
    
    func setUserPreferences(_ prefs: UserPreferences) {
        commandManager.setUserPreferences(prefs)
    }
    
    func setDisplaySettings(_ settings: DisplaySettings) {
        commandManager.setDisplaySettings(settings)
    }
    
    func setHeartRateMeasurementInterval(minutes: Int) {
        commandManager.setHeartRateMeasurementInterval(minutes: minutes)
    }
    
    func setSpO2AllDayMonitoring(enabled: Bool) {
        commandManager.setSpO2AllDayMonitoring(enabled: enabled)
    }
    
    func setStressMonitoring(enabled: Bool) {
        commandManager.setStressMonitoring(enabled: enabled)
    }
    
    func setHRVAllDayMonitoring(enabled: Bool) {
        commandManager.setHRVAllDayMonitoring(enabled: enabled)
    }
    
    func setTemperatureAllDayMonitoring(enabled: Bool) {
        commandManager.setTemperatureAllDayMonitoring(enabled: enabled)
    }
    
    func requestSettingsFromRing() {
        commandManager.requestSettingsFromRing()
    }
    
    func triggerManualHeartRate() {
        commandManager.triggerManualHeartRate()
    }
    
    // MARK: - Realtime Manager API
    
    func startRealtimeHeartRate() {
        realtimeManager.startRealtimeHeartRate()
    }
    
    func stopRealtimeHeartRate() {
        realtimeManager.stopRealtimeHeartRate()
    }
    
    func startRealtimeSteps() {
        realtimeManager.startRealtimeSteps()
    }
    
    func stopRealtimeSteps() {
        realtimeManager.stopRealtimeSteps()
    }
    
    // MARK: - Sync Manager API
    
    func fetchAllHistoricalData(completion: @escaping () -> Void) {
        self.syncCompletionCallback = completion
        syncManager.fetchAllHistoricalData()
    }
    
    func fetchHistoryHeartRate(daysAgo: Int = 0, completion: (([HeartRateSample]) -> Void)? = nil) {
        self.heartRateHistoryCallback = completion
        syncManager.fetchHistoryHeartRate(daysAgo: daysAgo)
    }
    
    func fetchHistoryHRV(daysAgo: Int = 0, completion: (([HRVSample]) -> Void)? = nil) {
        self.hrvHistoryCallback = completion
        syncManager.fetchHistoryHRV(daysAgo: daysAgo)
    }
    
    // MARK: - Storage Manager API
    
    func saveDataToEncryptedStorage() async throws {
        try await storageManager.saveAllData(
            heartRate: heartRateSamples,
            stress: stressSamples,
            spO2: spO2Samples,
            activity: activitySamples,
            hrv: hrvSamples,
            temperature: temperatureSamples,
            sleep: sleepRecords
        )
    }
    
    func loadDataFromEncryptedStorage() async throws {
        let data = try await storageManager.loadAllData()
        
        heartRateSamples = data.heartRate
        stressSamples = data.stress
        spO2Samples = data.spO2
        activitySamples = data.activity
        hrvSamples = data.hrv
        temperatureSamples = data.temperature
        sleepRecords = data.sleep
    }
    
    func deleteStoredData() async throws {
        try await storageManager.deleteAllData()
        
        // Clear in-memory data
        heartRateSamples.removeAll()
        stressSamples.removeAll()
        spO2Samples.removeAll()
        activitySamples.removeAll()
        hrvSamples.removeAll()
        temperatureSamples.removeAll()
        sleepRecords.removeAll()
    }
    
    func getStorageInfo() -> (sizeBytes: Int64, fileCount: Int) {
        (storageManager.getStorageSize(), storageManager.getFileCount())
    }
    
    // MARK: - HealthKit Manager API
    
    func requestHealthKitPermissions() async throws {
        try await healthKitManager.requestAuthorization()
    }
    
    func syncToHealthKit() async throws {
        guard healthKitManager.isAuthorized() else {
             try await requestHealthKitPermissions()
             return
         }
        
        try await healthKitManager.syncAllData(
            heartRate: heartRateSamples,
            activity: activitySamples,
            sleep: sleepRecords
        )
        
        // Sync additional data types
        try await healthKitManager.syncSpO2(spO2Samples)
        try await healthKitManager.syncHRV(hrvSamples)
        try await healthKitManager.syncTemperature(temperatureSamples)
    }
    
    func isHealthKitAuthorized() -> Bool {
        healthKitManager.isAuthorized()
    }
    
    // MARK: - Convenience Methods
    
    /// Sync data and automatically save to storage and HealthKit
    func syncAllDataWithAutoSave(enableHealthKit: Bool = true) async throws {
        // Sync from ring
        await withCheckedContinuation { continuation in
            fetchAllHistoricalData {
                continuation.resume()
            }
        }
        
        // Save to encrypted storage
        try await saveDataToEncryptedStorage()
        
        // Sync to HealthKit if enabled
        if enableHealthKit && isHealthKitAuthorized() {
            try await syncToHealthKit()
        }
    }
}
