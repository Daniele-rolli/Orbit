//
//  RingSessionManager.swift
//  Orbit
//
//  Main coordinator for Ring communication
//

import AccessorySetupKit
import BackgroundTasks
import CoreBluetooth
import Foundation
import SwiftUI
import UserNotifications

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

    var ringModel: RingConstants.RingModel = .unknown {
        didSet {
            print("Ring model identified: \(ringModel.rawValue)")
            print("  Temperature support: \(ringModel.supportsTemperature)")
            print("  Continuous temp:     \(ringModel.supportsContinuousTemperature)")
            print("  Has display:         \(ringModel.hasDisplay)")
        }
    }

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

    // Cumulative day totals pushed by the ring via 0x73/0x12 notification.
    // These are SEPARATE from activitySamples (which are per-slot deltas from historical sync).
    // Views should prefer these when available (more current), fall back to summing activitySamples.
    var liveStepTotal: Int = 0
    var liveCalorieTotal: Int = 0
    var liveDistanceTotal: Int = 0

    // Result of the last manual "measure now" heart rate tap — not a stream
    var latestMeasuredHeartRate: Int?

    // MARK: - Managers

    private var session = ASAccessorySession()
    private var manager: CBCentralManager?

    var bluetoothManager: BluetoothManager!
    var commandManager: CommandManager!
    var syncManager: SyncManager!
    var storageManager: StorageManager!

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
    /// True while a BLE sync chain is in progress. Guards against concurrent syncs.
    var isSyncing: Bool = false

    // MARK: - Initialization

    override init() {
        super.init()

        bluetoothManager = BluetoothManager(sessionManager: self)
        commandManager = CommandManager(sessionManager: self)
        syncManager = SyncManager(sessionManager: self)
        storageManager = StorageManager()

        session.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent)

        // Load persisted data immediately — UI shows local data before ring connects
        Task {
            try? await loadDataFromEncryptedStorage()
        }
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
        if peripheralConnected { disconnect() }
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

        let nameToMatch = ring.displayName
        let detectedModel = RingConstants.RingModel.from(advertisedName: nameToMatch)
        ringModel = detectedModel == .unknown
            ? (peripheral?.name.map(RingConstants.RingModel.from(advertisedName:)) ?? .unknown)
            : detectedModel

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
            ringModel = .unknown

        case .pickerDidPresent:
            pickerDismissed = false

        case .pickerDidDismiss:
            pickerDismissed = true

        default:
            print("Received event type \(event.eventType)")
        }
    }

    // MARK: - Post Connection Initialization

    /// Called after BLE services are discovered. Sends time, phone name, reads battery,
    /// restores saved monitoring preferences to the ring, then kicks off history sync.
    func postConnectInitialization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Re-detect model from BLE peripheral name if still unknown
            if self.ringModel == .unknown, let peripheralName = self.peripheral?.name {
                let detected = RingConstants.RingModel.from(advertisedName: peripheralName)
                if detected != .unknown { self.ringModel = detected }
            }

            self.commandManager.setPhoneName()
            self.commandManager.setDateTime()
            self.commandManager.requestBatteryInfo()
            self.commandManager.requestSettingsFromRing()

            // Reapply monitoring preferences (in case ring was factory-reset or replaced)
            self.restoreMonitoringPreferences()

            // Kick off historical data sync via the async path so pull-to-refresh
            // can coordinate with this sync without spawning a second parallel chain.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task { @MainActor in
                    await self.fetchAllHistoricalDataAsync()
                    try? await self.saveDataToEncryptedStorage()
                }
            }
        }
    }

    // MARK: - Monitoring Preferences

    /// Enable all monitoring features. Call after pairing or to reset defaults.
    func enableAllMonitoring() {
        let hrInterval = UserDefaults.standard.integer(forKey: "hrIntervalMinutes")
        setHeartRateMeasurementInterval(minutes: hrInterval > 0 ? hrInterval : 30)
        setSpO2AllDayMonitoring(enabled: true)
        setStressMonitoring(enabled: true)
        setHRVAllDayMonitoring(enabled: true)
        if ringModel.supportsTemperature {
            setTemperatureAllDayMonitoring(enabled: true)
        }
        // Persist defaults
        UserDefaults.standard.set(true, forKey: "spo2AllDay")
        UserDefaults.standard.set(true, forKey: "stressMonitoring")
        UserDefaults.standard.set(true, forKey: "hrvAllDay")
        UserDefaults.standard.set(true, forKey: "tempAllDay")
    }

    /// Restore monitoring preferences from UserDefaults to the ring.
    private func restoreMonitoringPreferences() {
        let defaults = UserDefaults.standard
        let hrInterval = defaults.integer(forKey: "hrIntervalMinutes")
        setHeartRateMeasurementInterval(minutes: hrInterval > 0 ? hrInterval : 30)
        setSpO2AllDayMonitoring(enabled: defaults.bool(forKey: "spo2AllDay"))
        setStressMonitoring(enabled: defaults.bool(forKey: "stressMonitoring"))
        setHRVAllDayMonitoring(enabled: defaults.bool(forKey: "hrvAllDay"))
        if ringModel.supportsTemperature {
            setTemperatureAllDayMonitoring(enabled: defaults.bool(forKey: "tempAllDay"))
        }
    }

    // MARK: - Battery Low Notification

    func sendLowBatteryNotification(level: Int) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard UserDefaults.standard.bool(forKey: "lowBatteryAlert") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ring Battery Low"
        content.body = "Your ring battery is at \(level)%. Please charge soon."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "lowBattery-\(level)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendDisconnectedNotification() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard UserDefaults.standard.bool(forKey: "deviceDisconnectedAlert") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ring Disconnected"
        content.body = "Orbit lost connection to your ring."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "disconnected-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Command Manager API

    func setPhoneName(name: String = "GB") { commandManager.setPhoneName(name: name) }
    func setDateTime() { commandManager.setDateTime() }
    func findDevice() { commandManager.findDevice() }
    func powerOff() { commandManager.powerOff() }
    func factoryReset() { commandManager.factoryReset() }

    func requestBatteryInfo(completion: ((BatteryInfo) -> Void)? = nil) {
        batteryStatusCallback = completion
        commandManager.requestBatteryInfo()
    }

    func setUserPreferences(_ prefs: UserPreferences) { commandManager.setUserPreferences(prefs) }

    func setDisplaySettings(_ settings: DisplaySettings) {
        guard ringModel.hasDisplay else {
            print("setDisplaySettings ignored — \(ringModel.rawValue) has no display")
            return
        }
        commandManager.setDisplaySettings(settings)
    }

    func setHeartRateMeasurementInterval(minutes: Int) { commandManager.setHeartRateMeasurementInterval(minutes: minutes) }
    func setSpO2AllDayMonitoring(enabled: Bool) { commandManager.setSpO2AllDayMonitoring(enabled: enabled) }
    func setStressMonitoring(enabled: Bool) { commandManager.setStressMonitoring(enabled: enabled) }
    func setHRVAllDayMonitoring(enabled: Bool) { commandManager.setHRVAllDayMonitoring(enabled: enabled) }

    func setTemperatureAllDayMonitoring(enabled: Bool) {
        guard ringModel.supportsTemperature else {
            print("setTemperatureAllDayMonitoring ignored — \(ringModel.rawValue) has no temperature sensor")
            return
        }
        commandManager.setTemperatureAllDayMonitoring(enabled: enabled)
    }

    func requestSettingsFromRing() { commandManager.requestSettingsFromRing() }
    func triggerManualHeartRate() { commandManager.triggerManualHeartRate() }

    // MARK: - Sync Manager API

    /// Async wrapper around the BLE sync chain. Serial — if a sync is already running
    /// this waits for it to complete rather than starting a second parallel chain.
    func fetchAllHistoricalDataAsync() async {
        // If already syncing, wait for it to finish rather than racing.
        if isSyncing {
            print("Sync already in progress — waiting for it to complete")
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let existing = syncCompletionCallback
                syncCompletionCallback = {
                    existing?()          // honour the original waiter
                    cont.resume()
                }
            }
            return
        }

        isSyncing = true

        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                var resumed = false
                syncCompletionCallback = {
                    guard !resumed else { return }
                    resumed = true
                    cont.resume()
                }
                syncManager.fetchAllHistoricalData()
            }
        } onCancel: {
            let cb = syncCompletionCallback
            syncCompletionCallback = nil
            cb?()
        }

        isSyncing = false
    }

    func fetchAllHistoricalData(completion: @escaping () -> Void) {
        // Delegate to the serial async path to avoid parallel sync chains.
        Task { @MainActor in
            await fetchAllHistoricalDataAsync()
            completion()
        }
    }

    func fetchHistoryHeartRate(daysAgo: Int = 0, completion: (([HeartRateSample]) -> Void)? = nil) {
        heartRateHistoryCallback = completion
    }

    func fetchHistoryHRV(daysAgo: Int = 0, completion: (([HRVSample]) -> Void)? = nil) {
        hrvHistoryCallback = completion
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

    // MARK: - Background Sync

    /// Register background app refresh task. Call from AppDelegate/Orbit.swift.
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.orbit.ring.sync", using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundSync(task: refreshTask)
        }
    }

    /// Schedule next background sync.
    static func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.orbit.ring.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleBackgroundSync(task: BGAppRefreshTask) {
        scheduleBackgroundSync() // Schedule next

        // Background sync just saves current in-memory data
        // Full BLE sync requires foreground; this preserves data across launches
        let manager = RingSessionManager()
        Task {
            try? await manager.saveDataToEncryptedStorage()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { task.setTaskCompleted(success: false) }
    }
}
