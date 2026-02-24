//
//  StepsView.swift
//  Orbit
//

import Charts
import SwiftUI

struct StepsView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .week
    @State private var showGoalSettings = false
    @State private var isLoading = false
    @State private var historicalSamples: [ActivitySample] = []

    // Goals — distance stored as km (Double)
    @AppStorage("stepsGoal") private var stepsGoal: Int = 10000
    @AppStorage("caloriesGoal") private var caloriesGoal: Int = 500
    @AppStorage("distanceGoalKm") private var distanceGoalKm: Double = 8.0
    @AppStorage("userMeasurementSystem") private var measurementSystem: Int = 0

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
                latestActivityCard
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
                Button { showGoalSettings = true } label: { Image(systemName: "target") }
            }
        }
        .sheet(isPresented: $showGoalSettings) {
            NavigationStack {
                GoalSettingsView(
                    stepsGoal: $stepsGoal,
                    caloriesGoal: $caloriesGoal,
                    distanceGoalKm: $distanceGoalKm
                )
            }
        }
        .refreshable { await loadFromStorage() }
        .task { await loadFromStorage() }
        .overlay {
            if isLoading {
                ProgressView("Loading history…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Data Loading

    private func loadFromStorage() async {
        isLoading = true
        historicalSamples = (try? await ring.storageManager.loadActivity()) ?? []
        isLoading = false
    }

    // MARK: - Daily Aggregation

    /// Most recent calendar day that has data
    private var mostRecentDay: Date? {
        guard let last = historicalSamples.last else { return nil }
        return Calendar.current.startOfDay(for: last.timestamp)
    }

    private var mostRecentDaySamples: [ActivitySample] {
        guard let day = mostRecentDay else { return [] }
        return historicalSamples.filter {
            Calendar.current.startOfDay(for: $0.timestamp) == day
        }
    }

    // Always use historical sync data — it is the authoritative source.
    // The live 0x73/0x12 push is cumulative since ring boot, not necessarily since midnight,
    // so preferring it over synced history caused phantom resets around 4 PM.
    private var todaySteps: Int {
        mostRecentDaySamples.reduce(0) { $0 + $1.steps }
    }
    private var todayCalories: Int {
        mostRecentDaySamples.reduce(0) { $0 + $1.calories }
    }

    private var todayDistanceMeters: Int {
        mostRecentDaySamples.reduce(0) { $0 + $1.distance }
    }
    private var todayDistanceKm: Double { Double(todayDistanceMeters) / 1000.0 }
}

// MARK: - Latest Activity Card

extension StepsView {
    private var latestActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LATEST SYNC")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                if let day = mostRecentDay {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption2)
                        if Calendar.current.isDateInToday(day) {
                            Text("Today")
                        } else if Calendar.current.isDateInYesterday(day) {
                            Text("Yesterday")
                        } else {
                            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        }
                    }
                    .foregroundStyle(.secondary).font(.caption)
                }
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    activityMetric(icon: "figure.walk", value: todaySteps.formatted(), label: "Steps", color: .green)
                    activityMetric(icon: "flame.fill", value: "\(todayCalories) Cal", label: "Calories", color: .red)
                    activityMetric(icon: "location.fill", value: formattedDistance(todayDistanceKm), label: "Distance", color: .cyan)
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

            if historicalSamples.isEmpty {
                Text("No recorded data — sync your ring to populate history")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func activityMetric(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3).fontWeight(.semibold)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Activity Rings Card

extension StepsView {
    private var activityRingsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                progressCard(title: "STEPS", current: todaySteps, goal: stepsGoal, color: .green, icon: "figure.walk",
                             currentLabel: todaySteps.formatted(), goalLabel: "\(stepsGoal.formatted())")
                progressCard(title: "CALORIES", current: todayCalories, goal: caloriesGoal, color: .red, icon: "flame.fill",
                             currentLabel: "\(todayCalories) Cal", goalLabel: "\(caloriesGoal) Cal")
            }

            // Distance — display & goal in km
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "location.fill").font(.caption).foregroundStyle(.cyan)
                    Text("DISTANCE").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(distanceProgress * 100))%").font(.caption).fontWeight(.semibold).foregroundStyle(.cyan)
                }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.cyan.opacity(0.2)).frame(height: 8)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4).fill(Color.cyan)
                            .frame(width: geo.size.width * CGFloat(distanceProgress), height: 8)
                    }.frame(height: 8)
                }
                HStack {
                    Text(formattedDistance(todayDistanceKm)).font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("of \(formattedDistance(distanceGoalKm))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.15)))
        }
    }

    private func progressCard(title: String, current: Int, goal: Int, color: Color, icon: String, currentLabel: String, goalLabel: String) -> some View {
        let prog = min(1.0, Double(current) / Double(max(1, goal)))
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(prog * 100))%").font(.caption).fontWeight(.semibold).foregroundStyle(color)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2)).frame(height: 8)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * CGFloat(prog), height: 8)
                }.frame(height: 8)
            }
            HStack {
                Text(currentLabel).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("of \(goalLabel)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
    }
}

// MARK: - Daily Stats Grid

extension StepsView {
    private var dailyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "AVG STEPS", value: "\(averageSteps.formatted())", subtitle: "per day", icon: "figure.walk", color: .green)
            statCard(title: "BEST DAY", value: "\(bestDaySteps.formatted())", subtitle: "steps", icon: "trophy.fill", color: .yellow)
            statCard(title: "ACTIVE DAYS", value: "\(activeDaysCount)", subtitle: "this \(selectedRange.rawValue.lowercased())", icon: "calendar.badge.checkmark", color: .blue)
            statCard(title: "STREAK", value: "\(currentStreak)", subtitle: "days", icon: "flame.fill", color: .orange)
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon).font(.title3).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }
}

// MARK: - Activity Trends Card

extension StepsView {
    private var activityTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity Trends").font(.title3).fontWeight(.semibold)
                Spacer()
                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 180)
            }

            if dailyAggregateSamples.isEmpty {
                emptyTrendsView
            } else {
                Chart {
                    ForEach(dailyAggregateSamples, id: \.date) { day in
                        BarMark(x: .value("Date", day.date), y: .value("Steps", day.steps))
                            .foregroundStyle(.green.gradient).cornerRadius(4)
                    }
                    RuleMark(y: .value("Goal", stepsGoal))
                        .foregroundStyle(.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal").font(.caption2).foregroundStyle(.green.opacity(0.7))
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { AxisGridLine(); AxisValueLabel(format: xAxisFormat) }
                }
                .frame(height: 200)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var emptyTrendsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar").font(.system(size: 48)).foregroundStyle(.secondary.opacity(0.5))
            Text("No Activity Data").font(.headline).foregroundStyle(.secondary)
            Text("Pull down to reload from storage").font(.caption).foregroundStyle(.secondary)
        }
        .frame(height: 200).frame(maxWidth: .infinity)
    }
}

// MARK: - Achievements Card

extension StepsView {
    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements").font(.headline)
            VStack(spacing: 12) {
                if allGoalsAchievedToday {
                    achievementRow(icon: "star.fill", title: "All Goals Completed!", description: "You hit all your targets on the latest sync", color: .yellow, isUnlocked: true)
                }
                achievementRow(icon: "flame.fill", title: "\(currentStreak) Day Streak", description: "Keep it up!", color: .orange, isUnlocked: currentStreak >= 3)
                achievementRow(icon: "figure.walk", title: "10K Steps", description: "Walk 10,000 steps in a day", color: .green, isUnlocked: todaySteps >= 10000)
                achievementRow(icon: "trophy.fill", title: "Week Warrior", description: "Hit your goal 7 days in a row", color: .blue, isUnlocked: currentStreak >= 7)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func achievementRow(icon: String, title: String, description: String, color: Color, isUnlocked: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.title3).foregroundStyle(isUnlocked ? color : .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(isUnlocked ? .green : .gray).font(isUnlocked ? .body : .caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Methods

extension StepsView {
    private var stepsProgress: Double { min(1.0, Double(todaySteps) / Double(max(1, stepsGoal))) }
    private var caloriesProgress: Double { min(1.0, Double(todayCalories) / Double(max(1, caloriesGoal))) }
    private var distanceProgress: Double { min(1.0, todayDistanceKm / max(0.001, distanceGoalKm)) }

    // Per-day aggregated samples for the chart (group 15-min slots into daily totals)
    private var dailyAggregateSamples: [(date: Date, steps: Int)] {
        let cal = Calendar.current
        let now = Date()
        let cutoff = now.addingTimeInterval(-Double(selectedRange.days) * 86400)
        let filtered = historicalSamples.filter { $0.timestamp > cutoff }

        var dict: [Date: Int] = [:]
        for s in filtered {
            let day = cal.startOfDay(for: s.timestamp)
            dict[day, default: 0] += s.steps
        }
        return dict.map { (date: $0.key, steps: $0.value) }.sorted { $0.date < $1.date }
    }

    private var filteredSamples: [ActivitySample] {
        let now = Date()
        let interval = Double(selectedRange.days) * 86400
        return historicalSamples.filter { $0.timestamp > now.addingTimeInterval(-interval) }
    }

    private var xAxisStride: Calendar.Component { selectedRange == .week ? .day : .weekOfYear }
    private var xAxisFormat: Date.FormatStyle { selectedRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day() }

    private var averageSteps: Int {
        guard !dailyAggregateSamples.isEmpty else { return 0 }
        return dailyAggregateSamples.map(\.steps).reduce(0, +) / dailyAggregateSamples.count
    }

    private var bestDaySteps: Int { dailyAggregateSamples.map(\.steps).max() ?? 0 }

    private var activeDaysCount: Int { dailyAggregateSamples.filter { $0.steps >= stepsGoal }.count }

    private var currentStreak: Int {
        var streak = 0
        let cal = Calendar.current
        var date = Date()
        for day in dailyAggregateSamples.sorted(by: { $0.date > $1.date }) {
            if cal.isDate(day.date, inSameDayAs: date) {
                if day.steps >= stepsGoal { streak += 1; date = cal.date(byAdding: .day, value: -1, to: date)! }
                else { break }
            }
        }
        return streak
    }

    private var allGoalsAchievedToday: Bool {
        todaySteps >= stepsGoal && todayCalories >= caloriesGoal && todayDistanceKm >= distanceGoalKm
    }

    /// Format distance respecting the user's measurement system preference
    private func formattedDistance(_ km: Double) -> String {
        if measurementSystem == 0 {
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.1f mi", km * 0.621371)
        }
    }
}

#Preview {
    NavigationStack { StepsView().environment(RingSessionManager()) }
}
