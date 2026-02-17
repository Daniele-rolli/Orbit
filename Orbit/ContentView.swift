//
//  ContentView.swift
//  Orbit
//
//

import AccessorySetupKit
import SleepChartKit
import SwiftUI

// MARK: - Widget Types

enum WidgetType: String, CaseIterable, Identifiable, Codable {
    case heartRate = "Heart Rate"
    case spo2 = "Blood Oxygen"
    case sleep = "Sleep"
    case steps = "Steps"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .spo2: return "lungs.fill"
        case .sleep: return "bed.double.fill"
        case .steps: return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .heartRate: return .red
        case .spo2: return .cyan
        case .sleep: return .blue
        case .steps: return .green
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
                ringSessionManager.startRealtimeSteps()
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
                    VStack(spacing: 16) {
                        ForEach(widgets) { widget in
                            widgetCard(for: widget)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
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

        await withCheckedContinuation { continuation in
            ringSessionManager.fetchAllHistoricalData {
                continuation.resume()
            }
        }

        try? await ringSessionManager.saveDataToEncryptedStorage()

        if ringSessionManager.isHealthKitAuthorized() {
            try? await ringSessionManager.syncToHealthKit()
        }

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

    private var latestHeartRate: Int? {
        if let realtime = ringSessionManager.realtimeHeartRate, realtime > 0 {
            return realtime
        }
        return ringSessionManager.heartRateSamples.last?.heartRate
    }

    private var recentSamples: [Int] {
        let samples = ringSessionManager.heartRateSamples.suffix(20)
        return samples.map { $0.heartRate }
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
                    HStack(alignment: .bottom, spacing: 1.5) {
                        ForEach(0 ..< recentSamples.count, id: \.self) { i in
                            Capsule()
                                .fill(Color.red.opacity(0.6))
                                .frame(width: 2, height: heartRateHeight(for: recentSamples[i]))
                        }
                    }
                    .frame(height: 32)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heartRateHeight(for heartRate: Int) -> CGFloat {
        let normalized = max(0, min(1, Double(heartRate - 40) / 80.0))
        return CGFloat(8 + normalized * 24)
    }
}

struct SPO2Widget: View {
    @Environment(RingSessionManager.self) var ringSessionManager

    private var latestSpO2: Int? {
        // Check realtime first
        if let realtime = ringSessionManager.realtimeSpO2, realtime > 0 {
            return realtime
        }
        // Fall back to latest sample
        return ringSessionManager.spO2Samples.last?.spO2
    }

    private var averageSpO2: Double? {
        guard !ringSessionManager.spO2Samples.isEmpty else { return nil }
        let sum = ringSessionManager.spO2Samples.reduce(0) { $0 + $1.spO2 }
        return Double(sum) / Double(ringSessionManager.spO2Samples.count)
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
    }
}

struct SleepWidget: View {
    @Environment(RingSessionManager.self) var ringSessionManager

    private var sleepSamples: [SleepSample] {
        ringSessionManager.sleepRecords.map { record in
            let stage: SleepStage = switch record.sleepType {
            case .deep: .asleepDeep
            case .light: .asleepCore
            case .rem: .asleepREM
            case .awake: .awake
            }
            return SleepSample(stage: stage, startDate: record.startTime, endDate: record.endTime)
        }
    }

    private var totalSleepMinutes: Int {
        sleepSamples
            .filter { $0.stage != .awake }
            .reduce(0) {
                $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60)
            }
    }

    private var durationText: (h: Int, m: Int) {
        (totalSleepMinutes / 60, totalSleepMinutes % 60)
    }

    private var bedtime: Date? {
        sleepSamples.map(\.startDate).min()
    }

    private var wakeTime: Date? {
        sleepSamples.map(\.endDate).max()
    }

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
                    if sleepSamples.isEmpty {
                        smallEmptyStateView
                    } else {
                        SleepTimelineGraph(samples: sleepSamples)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private var todaySteps: Int {
        return ringSessionManager.liveActivity.steps
    }

    private var todayCalories: Int {
        return ringSessionManager.liveActivity.calories
    }

    private var todayDistance: Double {
        // Distance in kilometers
        return Double(ringSessionManager.liveActivity.distance) / 1000.0
    }

    private var stepGoal: Int {
        return 10000
    }

    private var calorieGoal: Int {
        return 500 // Active calories goal
    }

    private var distanceGoal: Double {
        return 5.0 // 5 km
    }

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
                        Text("/ \(stepGoal.formatted()) steps")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("\(todayCalories)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("/ \(calorieGoal) cal")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.cyan)
                            .frame(width: 8, height: 8)
                        Text(String(format: "%.1f", todayDistance))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("/ \(String(format: "%.1f", distanceGoal)) km")
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
            stepsProgress = min(1.5, CGFloat(todaySteps) / CGFloat(stepGoal))
            caloriesProgress = min(1.5, CGFloat(todayCalories) / CGFloat(calorieGoal))
            distanceProgress = min(1.5, CGFloat(todayDistance / distanceGoal))
        }
    }
}

#Preview {
    ContentView(ringSessionManager: PreviewRingSessionManager())
}
