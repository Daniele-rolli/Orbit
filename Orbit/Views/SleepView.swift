//
//  SleepView.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/29/26.
//

import Charts
import SleepChartKit
import SwiftUI

struct SleepView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .week
    @State private var selectedDate: Date = .init()
    @State private var isLoading = false
    @State private var historicalSleepRecords: [SleepRecord] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var hrvSamples: [HRVSample] = []

    enum TimeRange: String, CaseIterable {
        case week = "Week", month = "Month", threeMonths = "3M"
        var days: Int { switch self { case .week: 7; case .month: 30; case .threeMonths: 90 } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sleepScoreCard
                sleepDurationCard
                sleepStagesChart        // SleepChartKit Gantt per night
                sleepTrendsCard         // ScreenTime-style stacked columns
                sleepBiometricsCard     // Lollipop HR, HRV, SpO2
                sleepStatsGrid
                sleepQualityCard
            }
            .padding()
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.large)
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

    private func loadFromStorage() async {
        isLoading = true
        async let sleep = (try? await ring.storageManager.loadSleep()) ?? []
        async let hr    = (try? await ring.storageManager.loadHeartRate()) ?? []
        async let hrv   = (try? await ring.storageManager.loadHRV()) ?? []
        historicalSleepRecords = await sleep
        heartRateSamples       = await hr
        hrvSamples             = await hrv
        isLoading = false
    }
}

// MARK: - Sleep Score Card

extension SleepView {
    private var sleepScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP SCORE")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(todaySleepScore)")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                            .foregroundStyle(scoreColor(todaySleepScore))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scoreLabel(todaySleepScore))
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(scoreColor(todaySleepScore))
                            if let cmp = weeklyComparison {
                                HStack(spacing: 2) {
                                    Image(systemName: cmp >= 0 ? "arrow.up.right" : "arrow.down.right").font(.caption2)
                                    Text("\(abs(cmp))").font(.caption2)
                                }
                                .foregroundStyle(cmp >= 0 ? .green : .red)
                            }
                        }
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(scoreColor(todaySleepScore).opacity(0.2), lineWidth: 12).frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(todaySleepScore) / 100.0)
                        .stroke(scoreColor(todaySleepScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                    Image(systemName: "moon.stars.fill").font(.system(size: 28)).foregroundStyle(scoreColor(todaySleepScore))
                }
            }
            if let s = todaySleepSession {
                HStack(spacing: 16) {
                    sleepTimeInfo(icon: "bed.double.fill",  time: s.bedTime,  label: "Bedtime")
                    Divider().frame(height: 30)
                    sleepTimeInfo(icon: "sunrise.fill",     time: s.wakeTime, label: "Wake up")
                    Divider().frame(height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDuration(s.totalSleep)).font(.subheadline).fontWeight(.semibold)
                        Text("Total sleep").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                Text("No sleep data for the most recent night.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func sleepTimeInfo(icon: String, time: Date, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(time, style: .time).font(.subheadline).fontWeight(.semibold)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score { case 80...100: .green; case 60..<80: .cyan; case 40..<60: .orange; default: .red }
    }
    private func scoreLabel(_ score: Int) -> String {
        switch score { case 80...100: "Excellent"; case 60..<80: "Good"; case 40..<60: "Fair"; default: "Poor" }
    }
}

// MARK: - Duration Card

extension SleepView {
    private var sleepDurationCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOTAL SLEEP").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatDuration(todayTotalSleep))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text("hrs").font(.callout).fontWeight(.medium).foregroundStyle(.secondary)
                }
                Text(sleepGoalText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                sleepDurationIndicator(value: todayDeepSleep,  total: todayTotalSleep, label: "Deep",  color: .purple)
                sleepDurationIndicator(value: todayLightSleep, total: todayTotalSleep, label: "Light", color: .blue)
                sleepDurationIndicator(value: todayREMSleep,   total: todayTotalSleep, label: "REM",   color: .green)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func sleepDurationIndicator(value: TimeInterval, total: TimeInterval, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.2)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * CGFloat(total > 0 ? value / total : 0), height: 4)
                }
            }.frame(height: 4)
            Text(formatDuration(value)).font(.caption).fontWeight(.medium).frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Sleep Stages Chart (SleepChartKit Gantt)

extension SleepView {
    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sleep Stages").font(.title3).fontWeight(.semibold)
                Spacer()
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date).labelsHidden()
            }

            if let session = sleepSessionForDate(selectedDate), !session.records.isEmpty {
                // SleepChartKit renders a beautiful Gantt chart — use SleepChart(session) once package is added.
                // Until then, we fall back to our existing SleepChartView:
                SleepChartView(records: session.records).frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz").font(.system(size: 48)).foregroundStyle(.secondary.opacity(0.5))
                    Text("No Sleep Data").font(.headline).foregroundStyle(.secondary)
                    Text("Select a different date").font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: 200).frame(maxWidth: .infinity)
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .purple, label: "Deep")
                legendItem(color: .blue,   label: "Light")
                legendItem(color: .green,  label: "REM")
                legendItem(color: .orange, label: "Awake")
            }.font(.caption)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sleep Trends — ScreenTime-style stacked columns

extension SleepView {
    private var sleepTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sleep Trends").font(.title3).fontWeight(.semibold)
                Spacer()
                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 180)
            }

            if filteredSleepSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar").font(.system(size: 48)).foregroundStyle(.secondary.opacity(0.5))
                    Text("No Trend Data").font(.headline).foregroundStyle(.secondary)
                }
                .frame(height: 180).frame(maxWidth: .infinity)
            } else {
                ScreenTimeStyleChart(
                    weekItems: weekScreenItems,
                    hourItems: hourScreenItems,
                    average: averageSleepHours,
                    yFormatter: { h in "\(Int(h))h" },
                    selectedDate: $selectedDate
                )

                // Legend
                HStack(spacing: 12) {
                    screenLegend(color: .purple, label: "Deep")
                    screenLegend(color: .blue,   label: "Light")
                    screenLegend(color: .green,  label: "REM")
                    screenLegend(color: .orange.opacity(0.6), label: "Awake")
                }.font(.caption)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func screenLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).foregroundStyle(.secondary)
        }
    }

    /// Build ScreenTimeStyleChart week items from sleep sessions.
    /// Each session → 4 items (deep/light/rem/awake), value in hours.
    private var weekScreenItems: [ScreenTimeStyleChart.Item] {
        filteredSleepSessions.flatMap { session in [
            ScreenTimeStyleChart.Item(date: session.date, category: "Deep",  value: session.deepSleep  / 3600, color: .purple),
            ScreenTimeStyleChart.Item(date: session.date, category: "Light", value: session.lightSleep / 3600, color: .blue),
            ScreenTimeStyleChart.Item(date: session.date, category: "REM",   value: session.remSleep   / 3600, color: .green),
            ScreenTimeStyleChart.Item(date: session.date, category: "Awake", value: session.awakeTime  / 3600, color: .orange.opacity(0.6))
        ]}
    }

    /// Build hourly items for the selected day's drill-down.
    /// We split each sleep record into its hour-start bucket.
    private var hourScreenItems: [ScreenTimeStyleChart.Item] {
        guard let session = sleepSessionForDate(selectedDate) else { return [] }
        var items: [ScreenTimeStyleChart.Item] = []
        for record in session.records {
            let duration = record.endTime.timeIntervalSince(record.startTime) / 3600  // hours
            let hourStart = Calendar.current.dateInterval(of: .hour, for: record.startTime)!.start
            let color: Color = {
                switch record.sleepType {
                case .deep: return .purple
                case .light: return .blue
                case .rem: return .green
                case .awake: return .orange.opacity(0.6)
                }
            }()
            items.append(ScreenTimeStyleChart.Item(
                date: hourStart,
                category: record.sleepType.displayName,
                value: duration,
                color: color
            ))
        }
        return items
    }

    private var averageSleepHours: Double {
        guard !filteredSleepSessions.isEmpty else { return 8 }
        return filteredSleepSessions.map { $0.totalSleep / 3600 }.reduce(0, +) / Double(filteredSleepSessions.count)
    }
}

// MARK: - During-Sleep Biometrics (Lollipop for HR, HRV)

extension SleepView {
    private var sleepBiometricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("During Sleep").font(.title3).fontWeight(.semibold)

            if let session = todaySleepSession {
                let sleepHR  = heartRateSamples.filter { $0.timestamp >= session.bedTime && $0.timestamp <= session.wakeTime }
                let sleepHRV = hrvSamples.filter       { $0.timestamp >= session.bedTime && $0.timestamp <= session.wakeTime }

                if sleepHR.isEmpty && sleepHRV.isEmpty {
                    Text("No heart rate or HRV data recorded during this sleep session.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if !sleepHR.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Heart Rate", systemImage: "heart.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                            biometricStats(values: sleepHR.map { Double($0.heartRate) }, unit: "bpm")
                            LollipopChart(
                                points: sleepHR.map {
                                    LollipopChart.Point(date: $0.timestamp,
                                                       value: Double($0.heartRate),
                                                       label: "\($0.heartRate) bpm")
                                },
                                color: .red, yLabel: "BPM",
                                yDomain: nil, xStride: .hour,
                                xFormat: .dateTime.hour(.defaultDigits(amPM: .abbreviated))
                            )
                            .frame(height: 110)
                        }
                    }

                    if !sleepHRV.isEmpty {
                        if !sleepHR.isEmpty { Divider() }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("HRV", systemImage: "waveform.path.ecg")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.cyan)
                            biometricStats(values: sleepHRV.map { Double($0.hrvValue) }, unit: "ms")
                            LollipopChart(
                                points: sleepHRV.map {
                                    LollipopChart.Point(date: $0.timestamp,
                                                       value: Double($0.hrvValue),
                                                       label: "\($0.hrvValue) ms")
                                },
                                color: .cyan, yLabel: "HRV",
                                yDomain: nil, xStride: .hour,
                                xFormat: .dateTime.hour(.defaultDigits(amPM: .abbreviated))
                            )
                            .frame(height: 110)
                        }
                    }
                }
            } else {
                Text("No sleep session found.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func biometricStats(values: [Double], unit: String) -> some View {
        HStack(spacing: 0) {
            miniStat("MIN", value: values.min().map { Int($0) }, unit: unit)
            Divider().frame(height: 32)
            miniStat("AVG", value: values.isEmpty ? nil : Int(values.reduce(0, +) / Double(values.count)), unit: unit)
            Divider().frame(height: 32)
            miniStat("MAX", value: values.max().map { Int($0) }, unit: unit)
        }
    }

    private func miniStat(_ label: String, value: Int?, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map(String.init) ?? "--").font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stats Grid

extension SleepView {
    private var sleepStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "AVG SLEEP",   value: formatDuration(averageSleep),     subtitle: "per night", icon: "moon.fill",                 color: .indigo)
            statCard(title: "AVG DEEP",    value: formatDuration(averageDeepSleep), subtitle: "per night", icon: "arrow.down.circle.fill",    color: .purple)
            statCard(title: "SLEEP DEBT",  value: formatDuration(sleepDebt),        subtitle: "this week", icon: "exclamationmark.triangle.fill", color: sleepDebt > 0 ? .orange : .green)
            statCard(title: "CONSISTENCY", value: "\(sleepConsistency)%",           subtitle: "this week", icon: "chart.line.uptrend.xyaxis", color: .cyan)
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

// MARK: - Quality Card

extension SleepView {
    private var sleepQualityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Quality Factors").font(.headline)
            VStack(spacing: 12) {
                qualityRow(title: "Consistency",   description: "Regular sleep schedule",   rating: sleepConsistency >= 80 ? .good : sleepConsistency >= 60 ? .fair : .poor)
                qualityRow(title: "Duration",      description: "7–9 hours recommended",    rating: todayTotalSleep >= 25200 && todayTotalSleep <= 32400 ? .good : .fair)
                qualityRow(title: "Deep Sleep",    description: "20–25% of total sleep",    rating: deepSleepPercentage >= 20 ? .good : deepSleepPercentage >= 15 ? .fair : .poor)
                qualityRow(title: "Interruptions", description: "Fewer is better",          rating: todayAwakeCount <= 2 ? .good : todayAwakeCount <= 4 ? .fair : .poor)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    enum QualityRating {
        case good, fair, poor
        var color: Color { switch self { case .good: .green; case .fair: .orange; case .poor: .red } }
        var icon: String { switch self { case .good: "checkmark.circle.fill"; case .fair: "exclamationmark.triangle.fill"; case .poor: "xmark.circle.fill" } }
    }

    private func qualityRow(title: String, description: String, rating: QualityRating) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rating.icon).font(.title3).foregroundStyle(rating.color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Model

extension SleepView {
    struct SleepSession {
        let date: Date
        let records: [SleepRecord]
        let bedTime: Date
        let wakeTime: Date
        let totalSleep: TimeInterval
        let deepSleep: TimeInterval
        let lightSleep: TimeInterval
        let remSleep: TimeInterval
        let awakeTime: TimeInterval
        let awakeCount: Int
        let score: Int

        init(records: [SleepRecord]) {
            let sorted = records.sorted { $0.startTime < $1.startTime }
            self.records = sorted
            guard let first = sorted.first, let last = sorted.last else {
                date = Date(); bedTime = Date(); wakeTime = Date()
                totalSleep = 0; deepSleep = 0; lightSleep = 0; remSleep = 0
                awakeTime = 0; awakeCount = 0; score = 0; return
            }
            bedTime = first.startTime; wakeTime = last.endTime
            date = Calendar.current.startOfDay(for: wakeTime)
            var deep: TimeInterval = 0, light: TimeInterval = 0, rem: TimeInterval = 0
            var awake: TimeInterval = 0, awakeSegs = 0
            for r in sorted {
                let d = r.endTime.timeIntervalSince(r.startTime)
                switch r.sleepType {
                case .deep: deep += d; case .light: light += d
                case .rem: rem += d; case .awake: awake += d; awakeSegs += 1
                }
            }
            deepSleep = deep; lightSleep = light; remSleep = rem
            awakeTime = awake; awakeCount = awakeSegs; totalSleep = deep + light + rem
            score = Self.score(total: totalSleep, deep: deep, rem: rem, awakeCount: awakeSegs)
        }

        static func score(total: TimeInterval, deep: TimeInterval, rem: TimeInterval, awakeCount: Int) -> Int {
            var s = 0
            let h = total / 3600
            s += h >= 7 && h <= 9 ? 40 : h >= 6 ? 30 : h >= 5 ? 20 : 10
            let dp = total > 0 ? (deep / total) * 100 : 0
            s += dp >= 20 && dp <= 25 ? 30 : dp >= 15 ? 20 : dp >= 10 ? 10 : 0
            let rp = total > 0 ? (rem / total) * 100 : 0
            s += rp >= 20 && rp <= 25 ? 15 : rp >= 15 ? 10 : rp >= 10 ? 5 : 0
            s += awakeCount <= 1 ? 15 : awakeCount <= 3 ? 10 : awakeCount <= 5 ? 5 : 0
            return min(100, s)
        }
    }

    private func groupSleepSessions() -> [SleepSession] {
        var sessions: [SleepSession] = [], group: [SleepRecord] = []
        for record in historicalSleepRecords.sorted(by: { $0.startTime < $1.startTime }) {
            if group.isEmpty { group.append(record) }
            else if let last = group.last, record.startTime.timeIntervalSince(last.endTime) > 3 * 3600 {
                sessions.append(SleepSession(records: group)); group = [record]
            } else { group.append(record) }
        }
        if !group.isEmpty { sessions.append(SleepSession(records: group)) }
        return sessions
    }
}

// MARK: - Computed Properties

extension SleepView {
    private var allSleepSessions: [SleepSession] { groupSleepSessions() }

    private var todaySleepSession: SleepSession? {
        if let s = sleepSessionForDate(Date()) { return s }
        let y = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if let s = sleepSessionForDate(y) { return s }
        return allSleepSessions.sorted { $0.wakeTime > $1.wakeTime }.first
    }

    private func sleepSessionForDate(_ date: Date) -> SleepSession? {
        allSleepSessions.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var filteredSleepSessions: [SleepSession] {
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.days) * 86400)
        return allSleepSessions.filter { $0.date > cutoff }
    }

    private var todaySleepScore: Int { todaySleepSession?.score ?? 0 }
    private var todayTotalSleep: TimeInterval { todaySleepSession?.totalSleep ?? 0 }
    private var todayDeepSleep: TimeInterval  { todaySleepSession?.deepSleep ?? 0 }
    private var todayLightSleep: TimeInterval { todaySleepSession?.lightSleep ?? 0 }
    private var todayREMSleep: TimeInterval   { todaySleepSession?.remSleep ?? 0 }
    private var todayAwakeCount: Int          { todaySleepSession?.awakeCount ?? 0 }
    private var deepSleepPercentage: Double   { todayTotalSleep > 0 ? (todayDeepSleep / todayTotalSleep) * 100 : 0 }

    private var weeklyComparison: Int? {
        guard let score = todaySleepSession?.score, !filteredSleepSessions.isEmpty else { return nil }
        let avg = filteredSleepSessions.prefix(7).map(\.score).reduce(0, +) / max(1, min(7, filteredSleepSessions.count))
        return score - avg
    }
    private var averageSleep: TimeInterval {
        guard !filteredSleepSessions.isEmpty else { return 0 }
        return filteredSleepSessions.map(\.totalSleep).reduce(0, +) / Double(filteredSleepSessions.count)
    }
    private var averageDeepSleep: TimeInterval {
        guard !filteredSleepSessions.isEmpty else { return 0 }
        return filteredSleepSessions.map(\.deepSleep).reduce(0, +) / Double(filteredSleepSessions.count)
    }
    private var sleepDebt: TimeInterval {
        let goal: TimeInterval = 8 * 3600
        let week = filteredSleepSessions.prefix(7)
        return max(0, goal * Double(week.count) - week.map(\.totalSleep).reduce(0, +))
    }
    private var sleepConsistency: Int {
        guard filteredSleepSessions.count >= 2 else { return 0 }
        let beds = filteredSleepSessions.map { $0.bedTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) }
        let avg = beds.reduce(0, +) / Double(beds.count)
        let dev = sqrt(beds.map { pow($0 - avg, 2) }.reduce(0, +) / Double(beds.count)) / 3600
        if dev < 1 { return 80 + Int((1 - dev) * 20) }
        else if dev < 2 { return 60 + Int((2 - dev) * 20) }
        else if dev < 3 { return 40 + Int((3 - dev) * 20) }
        return 40
    }
    private var sleepGoalText: String {
        let goal: TimeInterval = 8 * 3600; let diff = todayTotalSleep - goal
        if abs(diff) < 1800 { return "On target" }
        return diff > 0 ? "\(formatDuration(diff)) over goal" : "\(formatDuration(-diff)) short of goal"
    }
    private func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = Int(s) % 3600 / 60
        if h == 0 { return "\(m)m" }; if m == 0 { return "\(h)h" }; return "\(h)h \(m)m"
    }
}

// MARK: - SleepChartView (Gantt fallback — replace body with SleepChartKit once added)

struct SleepChartView: View {
    let records: [SleepRecord]

    private struct Mark: Identifiable {
        let id = UUID(); let start, end: Date; let label: String; let color: Color
    }
    private var marks: [Mark] {
        records.map { Mark(start: $0.startTime, end: $0.endTime, label: $0.sleepType.displayName, color: $0.sleepType.chartColor) }
    }

    var body: some View {
        Chart(marks) { m in
            RectangleMark(xStart: .value("Start", m.start), xEnd: .value("End", m.end), y: .value("Stage", m.label))
                .foregroundStyle(m.color.gradient).cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        }
        .chartYAxis { AxisMarks { AxisValueLabel() } }
        .frame(height: 200)
    }
}

#Preview {
    NavigationStack { SleepView().environment(RingSessionManager()) }
}
