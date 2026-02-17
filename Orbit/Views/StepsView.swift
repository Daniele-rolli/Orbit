//
//  StepsView.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/29/26.
//

import Charts
import SwiftUI

struct StepsView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .week
    @State private var showGoalSettings = false
    @State private var isRefreshing = false

    // Goals
    @AppStorage("stepsGoal") private var stepsGoal: Int = 10000
    @AppStorage("caloriesGoal") private var caloriesGoal: Int = 500
    @AppStorage("distanceGoal") private var distanceGoal: Int = 8000 // meters

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3M"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                liveActivityCard
                activityRingsCard
                dailyStatsGrid
                activityTrendsCard
                achievementsCard
            }
            .padding()
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGoalSettings = true
                } label: {
                    Image(systemName: "target")
                }
            }
        }
        .sheet(isPresented: $showGoalSettings) {
            GoalSettingsView(
                stepsGoal: $stepsGoal,
                caloriesGoal: $caloriesGoal,
                distanceGoal: $distanceGoal
            )
        }
        .refreshable {
            await refreshActivityData()
        }
    }

    private func refreshActivityData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Live Activity Card

extension StepsView {
    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TODAY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Live")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    activityMetric(
                        icon: "figure.walk",
                        value: "\(ring.liveActivity.steps)",
                        label: "Steps",
                        color: .green
                    )

                    activityMetric(
                        icon: "flame.fill",
                        value: "\(ring.liveActivity.calories)",
                        label: "Calories",
                        color: .red
                    )

                    activityMetric(
                        icon: "location.fill",
                        value: formatDistance(ring.liveActivity.distance),
                        label: "Distance",
                        color: .cyan
                    )
                }

                Spacer()

                StackedActivityRingView(
                    outterRingValue: .constant(stepsProgress),
                    middleRingValue: .constant(caloriesProgress),
                    innerRingValue: .constant(distanceProgress),
                    config: StackedActivityRingViewConfig(
                        lineWidth: 15,
                        outterRingColor: .green,
                        middleRingColor: .red,
                        innerRingColor: .cyan
                    )
                )
                .frame(width: 120, height: 120)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func activityMetric(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Activity Rings Card

extension StepsView {
    private var activityRingsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ringProgressIndicator(
                    title: "STEPS",
                    current: ring.liveActivity.steps,
                    goal: stepsGoal,
                    color: .green,
                    icon: "figure.walk"
                )

                ringProgressIndicator(
                    title: "CALORIES",
                    current: ring.liveActivity.calories,
                    goal: caloriesGoal,
                    color: .red,
                    icon: "flame.fill"
                )
            }

            ringProgressIndicator(
                title: "DISTANCE",
                current: ring.liveActivity.distance,
                goal: distanceGoal,
                color: .cyan,
                icon: "location.fill",
                unit: formatDistance(ring.liveActivity.distance),
                goalUnit: formatDistance(distanceGoal)
            )
        }
    }

    private func ringProgressIndicator(
        title: String,
        current: Int,
        goal: Int,
        color: Color,
        icon: String,
        unit: String? = nil,
        goalUnit: String? = nil
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(progress(current: current, goal: goal) * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 8)

                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress(current: current, goal: goal), height: 8)
                }
                .frame(height: 8)
            }

            HStack {
                Text(unit ?? "\(current)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("of \(goalUnit ?? "\(goal)")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Daily Stats Grid

extension StepsView {
    private var dailyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "AVG STEPS",
                value: "\(averageSteps)",
                subtitle: "per day",
                icon: "figure.walk",
                color: .green
            )

            statCard(
                title: "BEST DAY",
                value: "\(bestDaySteps)",
                subtitle: "steps",
                icon: "trophy.fill",
                color: .yellow
            )

            statCard(
                title: "ACTIVE DAYS",
                value: "\(activeDaysCount)",
                subtitle: "this \(selectedRange.rawValue.lowercased())",
                icon: "calendar.badge.checkmark",
                color: .blue
            )

            statCard(
                title: "STREAK",
                value: "\(currentStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Activity Trends Card

extension StepsView {
    private var activityTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity Trends")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if filteredSamples.isEmpty {
                emptyTrendsView
            } else {
                activityChart
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var activityChart: some View {
        Chart {
            ForEach(filteredSamples, id: \.timestamp) { sample in
                BarMark(
                    x: .value("Date", sample.timestamp),
                    y: .value("Steps", sample.steps)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(4)
            }

            // Goal line
            RuleMark(y: .value("Goal", stepsGoal))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) {
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 200)
    }

    private var emptyTrendsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Activity Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Pull down to refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievements Card

extension StepsView {
    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements")
                .font(.headline)

            VStack(spacing: 12) {
                if allGoalsAchievedToday {
                    achievementRow(
                        icon: "star.fill",
                        title: "All Goals Completed!",
                        description: "You hit all your targets today",
                        color: .yellow,
                        isUnlocked: true
                    )
                }

                achievementRow(
                    icon: "flame.fill",
                    title: "\(currentStreak) Day Streak",
                    description: "Keep it up!",
                    color: .orange,
                    isUnlocked: currentStreak >= 3
                )

                achievementRow(
                    icon: "figure.walk",
                    title: "10K Steps",
                    description: "Walk 10,000 steps in a day",
                    color: .green,
                    isUnlocked: ring.liveActivity.steps >= 10000
                )

                achievementRow(
                    icon: "trophy.fill",
                    title: "Week Warrior",
                    description: "Hit your goal 7 days in a row",
                    color: .blue,
                    isUnlocked: currentStreak >= 7
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func achievementRow(icon: String, title: String, description: String, color: Color, isUnlocked: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? color : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Methods

extension StepsView {
    private var stepsProgress: Double {
        progress(current: ring.liveActivity.steps, goal: stepsGoal)
    }

    private var caloriesProgress: Double {
        progress(current: ring.liveActivity.calories, goal: caloriesGoal)
    }

    private var distanceProgress: Double {
        progress(current: ring.liveActivity.distance, goal: distanceGoal)
    }

    private func progress(current: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }

    private var filteredSamples: [ActivitySample] {
        let now = Date()
        let interval = Double(selectedRange.days) * 86400
        return ring.activitySamples.filter {
            $0.timestamp > now.addingTimeInterval(-interval)
        }
    }

    private var xAxisStride: Calendar.Component {
        selectedRange == .week ? .day : .weekOfYear
    }

    private var xAxisFormat: Date.FormatStyle {
        selectedRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day()
    }

    private var averageSteps: Int {
        guard !filteredSamples.isEmpty else { return 0 }
        return filteredSamples.map(\.steps).reduce(0, +) / filteredSamples.count
    }

    private var bestDaySteps: Int {
        filteredSamples.map(\.steps).max() ?? 0
    }

    private var activeDaysCount: Int {
        filteredSamples.filter { $0.steps >= stepsGoal }.count
    }

    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()

        let sortedSamples = ring.activitySamples.sorted { $0.timestamp > $1.timestamp }

        for sample in sortedSamples {
            if calendar.isDate(sample.timestamp, inSameDayAs: currentDate) {
                if sample.steps >= stepsGoal {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                } else {
                    break
                }
            }
        }

        return streak
    }

    private var allGoalsAchievedToday: Bool {
        ring.liveActivity.steps >= stepsGoal &&
            ring.liveActivity.calories >= caloriesGoal &&
            ring.liveActivity.distance >= distanceGoal
    }

    private func formatDistance(_ meters: Int) -> String {
        let km = Double(meters) / 1000.0
        return String(format: "%.1f km", km)
    }
}

// MARK: - Goal Settings View

struct GoalSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var stepsGoal: Int
    @Binding var caloriesGoal: Int
    @Binding var distanceGoal: Int

    @State private var localStepsGoal: Double
    @State private var localCaloriesGoal: Double
    @State private var localDistanceGoal: Double

    init(stepsGoal: Binding<Int>, caloriesGoal: Binding<Int>, distanceGoal: Binding<Int>) {
        _stepsGoal = stepsGoal
        _caloriesGoal = caloriesGoal
        _distanceGoal = distanceGoal
        _localStepsGoal = State(initialValue: Double(stepsGoal.wrappedValue))
        _localCaloriesGoal = State(initialValue: Double(caloriesGoal.wrappedValue))
        _localDistanceGoal = State(initialValue: Double(distanceGoal.wrappedValue) / 1000.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(.green)
                            Text("Steps Goal")
                            Spacer()
                            Text("\(Int(localStepsGoal))")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $localStepsGoal, in: 1000 ... 30000, step: 500)
                            .tint(.green)
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Recommended: 10,000 steps per day")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.red)
                            Text("Calories Goal")
                            Spacer()
                            Text("\(Int(localCaloriesGoal))")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $localCaloriesGoal, in: 100 ... 2000, step: 50)
                            .tint(.red)
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text("Active calories burned through movement")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.cyan)
                            Text("Distance Goal")
                            Spacer()
                            Text(String(format: "%.1f km", localDistanceGoal))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $localDistanceGoal, in: 1 ... 20, step: 0.5)
                            .tint(.cyan)
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    Text("Total distance walked or run")
                }

                Section {
                    Button("Reset to Defaults") {
                        localStepsGoal = 10000
                        localCaloriesGoal = 500
                        localDistanceGoal = 8
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Activity Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        stepsGoal = Int(localStepsGoal)
                        caloriesGoal = Int(localCaloriesGoal)
                        distanceGoal = Int(localDistanceGoal * 1000)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StepsView()
            .environment(RingSessionManager())
    }
}
