//
//  ContentView.swift
//  Orbit
//
//

import AccessorySetupKit
import Charts
import SwiftUI

// MARK: - Widget Types

enum WidgetType: String, CaseIterable, Identifiable, Codable {
    case heartRate = "Heart Rate"
    case spo2 = "Blood Oxygen"
    case sleep = "Sleep"
    case steps = "Steps"
    case stress = "Stress"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .spo2: return "lungs.fill"
        case .sleep: return "bed.double.fill"
        case .steps: return "figure.walk"
        case .stress: return "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .heartRate: return .red
        case .spo2: return .cyan
        case .sleep: return .blue
        case .steps: return .green
        case .stress: return .purple
        }
    }
}

struct WidgetItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: WidgetType
    var order: Int

    init(type: WidgetType, order: Int, id: UUID? = nil) {
        self.id = id ?? UUID()
        self.type = type
        self.order = order
    }

    static func == (lhs: WidgetItem, rhs: WidgetItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @State var ringSessionManager = RingSessionManager()
    @State var batteryInfo: BatteryInfo?

    @State private var widgets: [WidgetItem] = [
        WidgetItem(type: .heartRate, order: 0),
        WidgetItem(type: .spo2, order: 1),
        WidgetItem(type: .sleep, order: 2),
        WidgetItem(type: .steps, order: 3),
        WidgetItem(type: .stress, order: 4)
    ]

    @State private var showingReorderSheet = false
    @State private var selectedTab = 0
    @State private var isRefreshing = false

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardView
                .tabItem {
                    Label("Summary", systemImage: "heart.text.square.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .environment(ringSessionManager)
        .onChange(of: ringSessionManager.peripheralReady) {
            if ringSessionManager.peripheralReady {
                ringSessionManager.requestBatteryInfo { info in
                    batteryInfo = info
                }
            }
        }
        .sheet(isPresented: $showingReorderSheet) {
            ReorderWidgetsSheet(widgets: $widgets)
        }
        .task {
            try? await ringSessionManager.loadDataFromEncryptedStorage()
        }
    }

    // MARK: - Dashboard View

    private var dashboardView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Sync progress banner — shown while the BLE sync chain is running
                    if ringSessionManager.isSyncing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.85)
                            Text("Syncing ring data…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    VStack(spacing: 16) {
                        ForEach(widgets) { widget in
                            widgetCard(for: widget)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, ringSessionManager.isSyncing ? 8 : 16)
                    .padding(.bottom, 24)
                }
                .animation(.easeInOut(duration: 0.3), value: ringSessionManager.isSyncing)
            }
            .refreshable {
                await refreshDashboard()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingReorderSheet = true
                    }) {
                        Text("Edit")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Widget Card

    private func widgetCard(for widget: WidgetItem) -> some View {
        NavigationLink(destination: destinationView(for: widget)) {
            Group {
                switch widget.type {
                case .heartRate:
                    HeartRateWidget()
                        .environment(ringSessionManager)
                case .spo2:
                    SPO2Widget()
                        .environment(ringSessionManager)
                case .sleep:
                    SleepWidget()
                        .environment(ringSessionManager)
                case .steps:
                    StepsWidget()
                        .environment(ringSessionManager)
                case .stress:
                    StressWidget()
                        .environment(ringSessionManager)
                }
            }
            .contentShape(Rectangle())
            .tint(.primary)
        }
    }

    @ViewBuilder
    private func destinationView(for widget: WidgetItem) -> some View {
        switch widget.type {
        case .heartRate:
            HeartRateView()
        case .spo2:
            SPO2View()
        case .sleep:
            SleepView()
        case .steps:
            StepsView()
        case .stress:
            StressView()
        }
    }

    // MARK: - Ring View

    private func makeRingView(ring: ASAccessory) -> some View {
        HStack {
            Image("colmi")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(ring.displayName)
                    .font(.headline)

                if let batteryInfo {
                    HStack(spacing: 6) {
                        BatteryView(isCharging: batteryInfo.charging, batteryLevel: batteryInfo.batteryLevel)
                        Text(batteryInfo.batteryLevel, format: .percent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Refresh Data

    @MainActor
    private func refreshDashboard() async {
        guard ringSessionManager.peripheralConnected else {
            print("Not connected to ring")
            return
        }

        isRefreshing = true
        await ringSessionManager.fetchAllHistoricalDataAsync()
        try? await ringSessionManager.saveDataToEncryptedStorage()
        isRefreshing = false
    }
}

// MARK: - Reorder Widgets Sheet

struct ReorderWidgetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var widgets: [WidgetItem]

    @State private var editingWidgets: [WidgetItem] = []
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach($editingWidgets) { $widget in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(widget.type.color)
                                .frame(width: 40, height: 40)

                            Image(systemName: widget.type.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text(widget.type.rawValue)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .onMove { fromOffsets, toOffset in
                    editingWidgets.move(fromOffsets: fromOffsets, toOffset: toOffset)
                    for index in editingWidgets.indices {
                        editingWidgets[index].order = index
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Customize Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        widgets = editingWidgets
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .environment(\.editMode, $editMode)
        }
        .onAppear {
            editingWidgets = widgets.map { WidgetItem(type: $0.type, order: $0.order, id: $0.id) }
        }
    }
}

// MARK: - Drop Delegate

struct DropViewDelegate: DropDelegate {
    let destinationItem: WidgetItem
    @Binding var items: [WidgetItem]
    @Binding var draggedItem: WidgetItem?

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedItem = draggedItem else { return }

        if draggedItem != destinationItem {
            let from = items.firstIndex(of: draggedItem)
            let to = items.firstIndex(of: destinationItem)

            if let from = from, let to = to {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)

                    for index in items.indices {
                        items[index].order = index
                    }
                }
            }
        }
    }
}

// MARK: - Widget Views

struct HeartRateWidget: View {
    @Environment(RingSessionManager.self) var ringSessionManager
    @State private var storageSamples: [HeartRateSample] = []

    private var latestHeartRate: Int? {
        storageSamples.last?.heartRate
    }

    private var recentSamples: [HeartRateSample] {
        Array(storageSamples.suffix(20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }

                Text("Heart Rate")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.red)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let hr = latestHeartRate {
                        Text("\(hr)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text("BPM")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !recentSamples.isEmpty {
                    Chart(recentSamples, id: \.timestamp) { s in
                        LineMark(
                            x: .value("Time", s.timestamp),
                            y: .value("BPM", s.heartRate)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: 80, height: 32)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            storageSamples = (try? await ringSessionManager.storageManager.loadHeartRate()) ?? []
        }
        .onChange(of: ringSessionManager.heartRateSamples) {
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadHeartRate()) ?? []
            }
        }
        .onChange(of: ringSessionManager.isSyncing) { _, syncing in
            guard !syncing else { return }
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadHeartRate()) ?? []
            }
        }
    }


}

struct SPO2Widget: View {
    @Environment(RingSessionManager.self) var ringSessionManager
    @State private var storageSamples: [SpO2Sample] = []

    private var latestSpO2: Int? {
        storageSamples.last?.spO2
    }

    private var averageSpO2: Double? {
        guard !storageSamples.isEmpty else { return nil }
        let sum = storageSamples.reduce(0) { $0 + $1.spO2 }
        return Double(sum) / Double(storageSamples.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Image(systemName: "lungs.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.cyan)
                }

                // Title
                Text("Blood Oxygen")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.cyan)

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .bottom, spacing: 12) {
                // Metric
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let spO2 = latestSpO2 {
                        Text("\(spO2)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text("%")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Average indicator
                if let avg = averageSpO2 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", avg))
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            storageSamples = (try? await ringSessionManager.storageManager.loadSpO2()) ?? []
        }
        .onChange(of: ringSessionManager.spO2Samples) {
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadSpO2()) ?? []
            }
        }
        .onChange(of: ringSessionManager.isSyncing) { _, syncing in
            guard !syncing else { return }
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadSpO2()) ?? []
            }
        }
    }
}

struct SleepWidget: View {
    @Environment(RingSessionManager.self) var ringSessionManager
    @State private var storageSleepRecords: [SleepRecord] = []

    private var sanitizedSleepRecords: [SleepRecord] {
        let now = Date()
        let latestAllowed = now.addingTimeInterval(2 * 86400)
        let earliestAllowed = now.addingTimeInterval(-180 * 86400)

        let filtered = storageSleepRecords.filter {
            $0.startTime >= earliestAllowed &&
                $0.endTime <= latestAllowed &&
                $0.endTime > $0.startTime
        }
        let deduped = Dictionary(
            filtered.map { ("\($0.startTime.timeIntervalSince1970)|\($0.endTime.timeIntervalSince1970)|\($0.sleepType.rawValue)", $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return deduped.values.sorted { $0.startTime < $1.startTime }
    }

    // Most recent sleep session records only
    private var recentRecords: [SleepRecord] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Group by session (records within 90m of each other form a session)
        let sorted = sanitizedSleepRecords
        var groups: [[SleepRecord]] = []
        var current: [SleepRecord] = []
        for r in sorted {
            if current.isEmpty || r.startTime.timeIntervalSince(current.last!.endTime) <= 90 * 60 {
                current.append(r)
            } else {
                groups.append(current)
                current = [r]
            }
        }
        if !current.isEmpty { groups.append(current) }
        let candidateGroups = groups
            .map { $0.sorted { $0.startTime < $1.startTime } }
            .filter { records in
                guard let wake = records.last?.endTime else { return false }
                return wake <= now.addingTimeInterval(6 * 3600) &&
                    calendar.startOfDay(for: wake) == today
            }

        func nonAwakeMinutes(_ records: [SleepRecord]) -> Int {
            records.filter { $0.sleepType != .awake }.reduce(0) { $0 + $1.durationMinutes }
        }
        func isLikelyMainSleep(_ records: [SleepRecord]) -> Bool {
            guard let first = records.first, let last = records.last else { return false }
            let cal = Calendar.current
            let bedHour = cal.component(.hour, from: first.startTime)
            let wakeHour = cal.component(.hour, from: last.endTime)
            let mins = nonAwakeMinutes(records)
            return (bedHour >= 18 || bedHour <= 6) && wakeHour <= 12 && mins >= 120 && mins <= 14 * 60
        }

        return candidateGroups.sorted {
            let lhsMain = isLikelyMainSleep($0) ? 1 : 0
            let rhsMain = isLikelyMainSleep($1) ? 1 : 0
            if lhsMain != rhsMain { return lhsMain > rhsMain }
            let lhsSleep = nonAwakeMinutes($0)
            let rhsSleep = nonAwakeMinutes($1)
            if lhsSleep != rhsSleep { return lhsSleep > rhsSleep }
            return ($0.last?.endTime ?? .distantPast) > ($1.last?.endTime ?? .distantPast)
        }.first ?? []
    }

    private var totalSleepMinutes: Int {
        recentRecords
            .filter { $0.sleepType != .awake }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var durationText: (h: Int, m: Int) {
        (totalSleepMinutes / 60, totalSleepMinutes % 60)
    }

    private var bedtime: Date? { recentRecords.map(\.startTime).min() }
    private var wakeTime: Date? { recentRecords.map(\.endTime).max() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Sleep", systemImage: "bed.double.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            // Main Content Row
            HStack(alignment: .center, spacing: 12) {
                // Left Side: Large Metrics
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(durationText.h)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("h")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("\(durationText.m)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .padding(.leading, 4)
                        Text("m")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let bed = bedtime, let wake = wakeTime {
                        Text("\(bed.formatted(.dateTime.hour().minute())) - \(wake.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right Side: Small Square Graph or Empty State
                Group {
                    if recentRecords.isEmpty {
                        smallEmptyStateView
                    } else {
                        MiniSleepChart(records: recentRecords)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task {
            storageSleepRecords = (try? await ringSessionManager.storageManager.loadSleep()) ?? []
        }
        .onChange(of: ringSessionManager.sleepRecords) {
            Task {
                storageSleepRecords = (try? await ringSessionManager.storageManager.loadSleep()) ?? []
            }
        }
        .onChange(of: ringSessionManager.isSyncing) { _, syncing in
            guard !syncing else { return }
            Task {
                storageSleepRecords = (try? await ringSessionManager.storageManager.loadSleep()) ?? []
            }
        }
    }

    /// Refactored Empty State for a small square layout
    private var smallEmptyStateView: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)

            Text("No Data")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 100)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StepsWidget: View {
    @Environment(RingSessionManager.self) var ringSessionManager
    @State private var storageSamples: [ActivitySample] = []

    private var validSamples: [ActivitySample] {
        let latestAllowed = Date().addingTimeInterval(6 * 3600)
        return storageSamples.filter { $0.timestamp <= latestAllowed }
    }

    private var latestSample: ActivitySample? {
        validSamples.max { $0.timestamp < $1.timestamp }
    }

    private var mostRecentDay: Date? {
        guard let last = latestSample else { return nil }
        return Calendar.current.startOfDay(for: last.timestamp)
    }

    private var todaySamples: [ActivitySample] {
        guard let day = mostRecentDay else { return [] }
        return validSamples.filter {
            Calendar.current.startOfDay(for: $0.timestamp) == day
        }
    }

    private var todaySteps: Int {
        todaySamples.reduce(0) { $0 + $1.steps }
    }

    private var todayCalories: Int {
        todaySamples.reduce(0) { $0 + $1.calories }
    }

    private var todayDistance: Double {
        Double(todaySamples.reduce(0) { $0 + $1.distance }) / 1000.0
    }
    
    @AppStorage("stepsGoal") private var stepsGoal: Int = 10000
    @AppStorage("caloriesGoal") private var caloriesGoal: Int = 500
    @AppStorage("distanceGoalKm") private var distanceGoalKm: Double = 8.0

    @State private var stepsProgress: CGFloat = 0.0
    @State private var caloriesProgress: CGFloat = 0.0
    @State private var distanceProgress: CGFloat = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }

                Text("Activity")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.green)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("\(todaySteps.formatted())")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("/ \(stepsGoal.formatted()) steps")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("\(todayCalories)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("/ \(caloriesGoal) Cal")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.cyan)
                            .frame(width: 8, height: 8)
                        Text(String(format: "%.1f", todayDistance))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("/ \(String(format: "%.1f", distanceGoalKm)) km")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Activity Rings
                StackedActivityRingView(
                    outterRingValue: $stepsProgress,
                    middleRingValue: $caloriesProgress,
                    innerRingValue: $distanceProgress,
                    config: StackedActivityRingViewConfig(
                        lineWidth: 8,
                        outterRingColor: .green,
                        middleRingColor: .red,
                        innerRingColor: .cyan
                    )
                )
                .frame(width: 80, height: 80)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            storageSamples = (try? await ringSessionManager.storageManager.loadActivity()) ?? []
            updateProgress()
        }
        .onChange(of: ringSessionManager.activitySamples) {
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadActivity()) ?? []
                updateProgress()
            }
        }
        .onChange(of: ringSessionManager.isSyncing) { _, syncing in
            guard !syncing else { return }
            Task {
                storageSamples = (try? await ringSessionManager.storageManager.loadActivity()) ?? []
                updateProgress()
            }
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: todaySteps) { _, _ in
            updateProgress()
        }
        .onChange(of: todayCalories) { _, _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            stepsProgress = min(1.5, CGFloat(todaySteps) / CGFloat(stepsGoal))
            caloriesProgress = min(1.5, CGFloat(todayCalories) / CGFloat(caloriesGoal))
            distanceProgress = min(1.5, CGFloat(todayDistance / distanceGoalKm))
        }
    }
}

struct StressWidget: View {
    @Environment(RingSessionManager.self) var ring
    @State private var storageSamples: [StressSample] = []

    // Most recent reading
    private var latestLevel: Int? { storageSamples.last?.stressLevel }

    // Last 12 readings for the sparkline
    private var recentSamples: [StressSample] { Array(storageSamples.suffix(12)) }

    // Today's average
    private var avgToday: Int? {
        let today = storageSamples.filter { Calendar.current.isDateInToday($0.timestamp) }
        guard !today.isEmpty else { return nil }
        return today.map(\.stressLevel).reduce(0, +) / today.count
    }

    private func stressColor(_ level: Int) -> Color {
        switch level {
        case ..<30:   return .mint
        case 30..<60: return .green
        case 60..<80: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple)

                Text("Stress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.purple)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            // Metric row
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(latestLevel.map(String.init) ?? "--")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(latestLevel.map { stressColor($0) } ?? .secondary)
                            .contentTransition(.numericText())

                        Text("/100")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Zone label + avg
                    HStack(spacing: 6) {
                        if let level = latestLevel {
                            Capsule()
                                .fill(stressColor(level).opacity(0.15))
                                .overlay {
                                    Text(RingConstants.stressLabel(for: level))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(stressColor(level))
                                }
                                .frame(height: 20)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        if let avg = avgToday {
                            Text("Avg \(avg) today")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Sparkline chart
                if !recentSamples.isEmpty {
                    Chart {
                        ForEach(recentSamples, id: \.timestamp) { sample in
                            BarMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("Stress", sample.stressLevel)
                            )
                            .foregroundStyle(stressColor(sample.stressLevel).gradient)
                            .cornerRadius(2)
                        }
                        // Threshold rules at 30, 60, 80
                        RuleMark(y: .value("", 30))
                            .foregroundStyle(.green.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        RuleMark(y: .value("", 60))
                            .foregroundStyle(.orange.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 0 ... 100)
                    .frame(width: 80, height: 44)
                } else {
                    // Empty bars placeholder
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0 ..< 8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 7, height: CGFloat.random(in: 8 ... 28))
                        }
                    }
                    .frame(width: 80, height: 44)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            storageSamples = (try? await ring.storageManager.loadStress()) ?? []
        }
        .onChange(of: ring.stressSamples) {
            Task {
                storageSamples = (try? await ring.storageManager.loadStress()) ?? []
            }
        }
    }
}

// MARK: - Mini Sleep Chart (widget thumbnail)

struct MiniSleepChart: View {
    let records: [SleepRecord]

    var body: some View {
        Chart(records, id: \.startTime) { r in
            RectangleMark(
                xStart: .value("Start", r.startTime),
                xEnd: .value("End", r.endTime),
                y: .value("Stage", r.sleepType.displayName)
            )
            .foregroundStyle(r.sleepType.chartColor.gradient)
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(4)
        .background(Color(.tertiarySystemFill))
    }
}

#Preview {
    ContentView(ringSessionManager: PreviewRingSessionManager())
}
