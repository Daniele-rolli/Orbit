//
//  SettingsView.swift
//  Orbit
//

import AccessorySetupKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var batteryInfo: BatteryInfo?

    // Monitoring preferences
    @AppStorage("hrIntervalMinutes") private var hrIntervalMinutes: Int = 30
    @AppStorage("spo2AllDay") private var spo2AllDay: Bool = true
    @AppStorage("stressMonitoring") private var stressMonitoring: Bool = true
    @AppStorage("hrvAllDay") private var hrvAllDay: Bool = true
    @AppStorage("tempAllDay") private var tempAllDay: Bool = true

    // User profile
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userAge") private var userAge: Int = 30
    @AppStorage("userHeightCm") private var userHeightCm: Int = 170
    @AppStorage("userWeightKg") private var userWeightKg: Int = 70
    @AppStorage("userMeasurementSystem") private var userMeasurementSystem: Int = 0
    @AppStorage("userTimeFormat") private var userTimeFormat: Int = 0

    // Notifications
    @State private var notificationsEnabled = false
    @State private var lowBatteryAlert = true
    @State private var deviceDisconnectedAlert = false

    // Goals
    @AppStorage("stepsGoal") private var stepsGoal: Int = 10000
    @AppStorage("caloriesGoal") private var caloriesGoal: Int = 500
    @AppStorage("distanceGoalKm") private var distanceGoalKm: Double = 8.0

    @State private var showDeleteConfirmation = false
    @State private var showGoalSettings = false

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                monitoringSection
                heartRateIntervalSection
                userProfileSection
                goalsSection
                notificationsSection
                dangerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .confirmationDialog("Delete all stored ring data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) {
                    Task { try? await ring.deleteStoredData() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Device

    private var deviceSection: some View {
        Section("MY RING") {
            if ring.pickerDismissed, let currentRing = ring.currentRing {
                HStack {
                    Image("colmi").resizable().aspectRatio(contentMode: .fit).frame(height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentRing.displayName).font(.headline.weight(.semibold))
                        if let b = batteryInfo {
                            HStack(spacing: 5) {
                                BatteryView(isCharging: b.charging, batteryLevel: b.batteryLevel)
                                Text(b.batteryLevel, format: .percent).font(.footnote).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Tap to refresh battery").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(ring.peripheralConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    ring.requestBatteryInfo { info in
                        DispatchQueue.main.async { batteryInfo = info }
                    }
                }
                .onAppear {
                    ring.requestBatteryInfo { info in
                        DispatchQueue.main.async { batteryInfo = info }
                    }
                }

                if ring.peripheralConnected {
                    Button("Find Ring") { ring.findDevice() }
                }
            } else {
                Button {
                    ring.presentPicker()
                } label: {
                    Label("Add Ring", systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: - Monitoring

    private var monitoringSection: some View {
        Section {
            Toggle("Blood Oxygen (24h)", isOn: $spo2AllDay)
                .onChange(of: spo2AllDay) { _, v in
                    ring.setSpO2AllDayMonitoring(enabled: v)
                }

            Toggle("Stress Monitoring (24h)", isOn: $stressMonitoring)
                .onChange(of: stressMonitoring) { _, v in
                    ring.setStressMonitoring(enabled: v)
                }

            Toggle("HRV Monitoring (24h)", isOn: $hrvAllDay)
                .onChange(of: hrvAllDay) { _, v in
                    ring.setHRVAllDayMonitoring(enabled: v)
                }

            if ring.ringModel.supportsTemperature {
                Toggle("Temperature (24h)", isOn: $tempAllDay)
                    .onChange(of: tempAllDay) { _, v in
                        ring.setTemperatureAllDayMonitoring(enabled: v)
                    }
            }
        } header: {
            Text("CONTINUOUS MONITORING")
        } footer: {
            Text("Enables automatic measurements throughout the day.")
        }
    }

    // MARK: - Heart Rate Interval

    private var heartRateIntervalSection: some View {
        Section {
            Picker("HR Measurement Interval", selection: $hrIntervalMinutes) {
                Text("Off").tag(0)
                Text("Every 5 min").tag(5)
                Text("Every 10 min").tag(10)
                Text("Every 15 min").tag(15)
                Text("Every 30 min").tag(30)
                Text("Every 45 min").tag(45)
                Text("Every 60 min").tag(60)
            }
            .onChange(of: hrIntervalMinutes) { _, v in
                ring.setHeartRateMeasurementInterval(minutes: v)
            }
        } header: {
            Text("HEART RATE")
        } footer: {
            Text("How often the ring automatically measures your heart rate. Lower intervals use more battery.")
        }
    }

    // MARK: - User Profile

    private var userProfileSection: some View {
        Section("YOUR PROFILE") {
            NavigationLink {
                UserProfileEditView(
                    gender: $userGender,
                    age: $userAge,
                    heightCm: $userHeightCm,
                    weightKg: $userWeightKg,
                    measurementSystem: $userMeasurementSystem,
                    timeFormat: $userTimeFormat,
                    onSave: { sendUserPrefsToRing() }
                )
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileSummary).font(.system(size: 15))
                        Text("Tap to edit").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var profileSummary: String {
        let genderStr = ["Male", "Female", "Other"][safe: userGender] ?? "Unknown"
        let heightStr = userMeasurementSystem == 0 ? "\(userHeightCm) cm" : {
            let inches = Int(Double(userHeightCm) / 2.54)
            return "\(inches / 12)'\(inches % 12)\""
        }()
        let weightStr = userMeasurementSystem == 0 ? "\(userWeightKg) kg" : "\(Int(Double(userWeightKg) * 2.205)) lbs"
        return "\(genderStr), \(userAge) yrs · \(heightStr) · \(weightStr)"
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section("ACTIVITY GOALS") {
            HStack {
                Image(systemName: "figure.walk").foregroundStyle(.green)
                Text("Steps")
                Spacer()
                Text("\(stepsGoal.formatted())").foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.red)
                Text("Calories")
                Spacer()
                Text("\(caloriesGoal) Cal").foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "location.fill").foregroundStyle(.cyan)
                Text("Distance")
                Spacer()
                Text(String(format: "%.1f km", distanceGoalKm)).foregroundStyle(.secondary)
            }

            NavigationLink("Edit Goals") {
                GoalSettingsView(
                    stepsGoal: $stepsGoal,
                    caloriesGoal: $caloriesGoal,
                    distanceGoalKm: $distanceGoalKm
                )
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, v in
                    if v { requestNotificationPermission() }
                }

            if notificationsEnabled {
                Toggle("Low Battery Alert", isOn: $lowBatteryAlert)
                Toggle("Ring Disconnected", isOn: $deviceDisconnectedAlert)
            }
        } header: {
            Text("NOTIFICATIONS")
        } footer: {
            Text("Receive alerts about your ring's battery and connection status.")
        }
        .onAppear { checkNotificationStatus() }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete All Health Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }

            if ring.currentRing != nil {
                Button(role: .destructive) {
                    ring.removeRing()
                } label: {
                    Label("Remove Ring", systemImage: "minus.circle")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sendUserPrefsToRing() {
        let prefs = UserPreferences(
            gender: UserPreferences.Gender(rawValue: UInt8(userGender)) ?? .male,
            age: userAge,
            heightCm: userHeightCm,
            weightKg: userWeightKg,
            measurementSystem: UserPreferences.MeasurementSystem(rawValue: UInt8(userMeasurementSystem)) ?? .metric,
            timeFormat: UserPreferences.TimeFormat(rawValue: UInt8(userTimeFormat)) ?? .twentyFourHour,
            systolicBP: 120,
            diastolicBP: 80,
            hrWarningThreshold: 180
        )
        ring.setUserPreferences(prefs)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if !granted {
                    // Open Settings if denied
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
}

// MARK: - User Profile Edit View

struct UserProfileEditView: View {
    @Binding var gender: Int
    @Binding var age: Int
    @Binding var heightCm: Int
    @Binding var weightKg: Int
    @Binding var measurementSystem: Int
    @Binding var timeFormat: Int
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("PERSONAL") {
                Picker("Biological Sex", selection: $gender) {
                    Text("Male").tag(0)
                    Text("Female").tag(1)
                    Text("Other").tag(2)
                }
                Stepper("Age: \(age) yrs", value: $age, in: 10...99)
            }

            Section("BODY MEASUREMENTS") {
                Stepper(heightLabel, value: $heightCm, in: 100...220)
                Stepper(weightLabel, value: $weightKg, in: 30...200)
            }

            Section("PREFERENCES") {
                Picker("Units", selection: $measurementSystem) {
                    Text("Metric").tag(0)
                    Text("Imperial").tag(1)
                }
                Picker("Time Format", selection: $timeFormat) {
                    Text("24-hour").tag(0)
                    Text("12-hour").tag(1)
                }
            }
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var heightLabel: String {
        if measurementSystem == 0 { return "Height: \(heightCm) cm" }
        let inches = Int(Double(heightCm) / 2.54)
        return "Height: \(inches / 12)'\(inches % 12)\""
    }

    private var weightLabel: String {
        if measurementSystem == 0 { return "Weight: \(weightKg) kg" }
        return "Weight: \(Int(Double(weightKg) * 2.205)) lbs"
    }
}

// MARK: - Goal Settings View

struct GoalSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var stepsGoal: Int
    @Binding var caloriesGoal: Int
    @Binding var distanceGoalKm: Double

    @State private var localSteps: Double
    @State private var localCalories: Double
    @State private var localDistance: Double

    init(stepsGoal: Binding<Int>, caloriesGoal: Binding<Int>, distanceGoalKm: Binding<Double>) {
        _stepsGoal = stepsGoal
        _caloriesGoal = caloriesGoal
        _distanceGoalKm = distanceGoalKm
        _localSteps = State(initialValue: Double(stepsGoal.wrappedValue))
        _localCalories = State(initialValue: Double(caloriesGoal.wrappedValue))
        _localDistance = State(initialValue: distanceGoalKm.wrappedValue)
    }

    var body: some View {
        Form {
            Section { sliderRow(icon: "figure.walk", color: .green, title: "Steps Goal", value: $localSteps, range: 1000...30000, step: 500, label: "\(Int(localSteps))") } header: { Text("Steps") } footer: { Text("Recommended: 10,000 steps per day") }

            Section { sliderRow(icon: "flame.fill", color: .red, title: "Calories Goal", value: $localCalories, range: 100...2000, step: 50, label: "\(Int(localCalories)) Cal") } header: { Text("Calories") } footer: { Text("Active calories burned through movement") }

            Section { sliderRow(icon: "location.fill", color: .cyan, title: "Distance Goal", value: $localDistance, range: 1...20, step: 0.5, label: String(format: "%.1f km", localDistance)) } header: { Text("Distance") } footer: { Text("Total distance walked or run") }

            Section {
                Button("Reset to Defaults") {
                    localSteps = 10000; localCalories = 500; localDistance = 8
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Activity Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    stepsGoal = Int(localSteps)
                    caloriesGoal = Int(localCalories)
                    distanceGoalKm = localDistance
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func sliderRow(icon: String, color: Color, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title)
                Spacer()
                Text(label).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step).tint(color)
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    SettingsView().environment(RingSessionManager())
}
