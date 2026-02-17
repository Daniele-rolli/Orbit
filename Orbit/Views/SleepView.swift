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
    @State private var isRefreshing = false

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
                sleepScoreCard
                sleepDurationCard
                sleepStagesChart
                sleepTrendsCard
                sleepStatsGrid
                sleepQualityCard
            }
            .padding()
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshSleepData()
        }
    }

    private func refreshSleepData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Sleep Score Card

extension SleepView {
    private var sleepScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP SCORE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(todaySleepScore)")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                            .foregroundStyle(scoreColor(todaySleepScore))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(scoreLabel(todaySleepScore))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(scoreColor(todaySleepScore))

                            if let comparison = weeklyComparison {
                                HStack(spacing: 2) {
                                    Image(systemName: comparison >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption2)
                                    Text("\(abs(comparison))")
                                        .font(.caption2)
                                }
                                .foregroundStyle(comparison >= 0 ? .green : .red)
                            }
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(scoreColor(todaySleepScore).opacity(0.2), lineWidth: 12)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(todaySleepScore) / 100.0)
                        .stroke(scoreColor(todaySleepScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(scoreColor(todaySleepScore))
                }
            }

            if let session = todaySleepSession {
                HStack(spacing: 16) {
                    sleepTimeInfo(
                        icon: "bed.double.fill",
                        time: session.bedTime,
                        label: "Bedtime"
                    )

                    Divider().frame(height: 30)

                    sleepTimeInfo(
                        icon: "sunrise.fill",
                        time: session.wakeTime,
                        label: "Wake up"
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func sleepTimeInfo(icon: String, time: Date, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(time, style: .time)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80 ... 100: return .green
        case 60 ..< 80: return .cyan
        case 40 ..< 60: return .orange
        default: return .red
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 80 ... 100: return "Excellent"
        case 60 ..< 80: return "Good"
        case 40 ..< 60: return "Fair"
        default: return "Poor"
        }
    }
}

// MARK: - Sleep Duration Card

extension SleepView {
    private var sleepDurationCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOTAL SLEEP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatDuration(todayTotalSleep))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))

                    Text("hrs")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text(sleepGoalText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                sleepDurationIndicator(
                    value: todayDeepSleep,
                    total: todayTotalSleep,
                    label: "Deep",
                    color: .purple
                )

                sleepDurationIndicator(
                    value: todayLightSleep,
                    total: todayTotalSleep,
                    label: "Light",
                    color: .blue
                )

                sleepDurationIndicator(
                    value: todayREMSleep,
                    total: todayTotalSleep,
                    label: "REM",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func sleepDurationIndicator(value: TimeInterval, total: TimeInterval, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(total > 0 ? value / total : 0), height: 4)
                }
            }
            .frame(height: 4)

            Text(formatDuration(value))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Sleep Stages Chart

extension SleepView {
    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sleep Stages")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
            }

            if let session = sleepSessionForDate(selectedDate), !session.records.isEmpty {
                SleepChartView(records: session.records)
                    .frame(height: 200)
            } else {
                emptyChartView
            }

            sleepStageLegend
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var sleepStageLegend: some View {
        HStack(spacing: 16) {
            legendItem(color: .purple, label: "Deep")
            legendItem(color: .blue, label: "Light")
            legendItem(color: .green, label: "REM")
            legendItem(color: .orange, label: "Awake")
        }
        .font(.caption)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Sleep Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Select a different date")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sleep Trends Card

extension SleepView {
    private var sleepTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sleep Trends")
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

            if filteredSleepSessions.isEmpty {
                emptyTrendsView
            } else {
                sleepTrendsChart
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var sleepTrendsChart: some View {
        Chart {
            ForEach(filteredSleepSessions, id: \.date) { session in
                BarMark(
                    x: .value("Date", session.date),
                    y: .value("Hours", session.totalSleep / 3600)
                )
                .foregroundStyle(.indigo.gradient)
                .cornerRadius(4)
            }

            // Goal line at 8 hours
            RuleMark(y: .value("Goal", 8.0))
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
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel(content: {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(doubleValue, specifier: "%.0f")h")
                    }
                })
            }
        }
        .chartYScale(domain: 0 ... 10)
        .frame(height: 180)
    }

    private var emptyTrendsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Trend Data")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sleep Stats Grid

extension SleepView {
    private var sleepStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "AVG SLEEP",
                value: formatDuration(averageSleep),
                subtitle: "per night",
                icon: "moon.fill",
                color: .indigo
            )

            statCard(
                title: "AVG DEEP",
                value: formatDuration(averageDeepSleep),
                subtitle: "per night",
                icon: "arrow.down.circle.fill",
                color: .purple
            )

            statCard(
                title: "SLEEP DEBT",
                value: formatDuration(sleepDebt),
                subtitle: "this week",
                icon: "exclamationmark.triangle.fill",
                color: sleepDebt > 0 ? .orange : .green
            )

            statCard(
                title: "CONSISTENCY",
                value: "\(sleepConsistency)%",
                subtitle: "this week",
                icon: "chart.line.uptrend.xyaxis",
                color: .cyan
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

// MARK: - Sleep Quality Card

extension SleepView {
    private var sleepQualityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Quality Factors")
                .font(.headline)

            VStack(spacing: 12) {
                qualityRow(
                    title: "Consistency",
                    description: "Regular sleep schedule",
                    rating: sleepConsistency >= 80 ? .good : sleepConsistency >= 60 ? .fair : .poor
                )

                qualityRow(
                    title: "Duration",
                    description: "7-9 hours recommended",
                    rating: todayTotalSleep >= 25200 && todayTotalSleep <= 32400 ? .good : .fair
                )

                qualityRow(
                    title: "Deep Sleep",
                    description: "20-25% of total sleep",
                    rating: deepSleepPercentage >= 20 ? .good : deepSleepPercentage >= 15 ? .fair : .poor
                )

                qualityRow(
                    title: "Interruptions",
                    description: "Fewer is better",
                    rating: todayAwakeCount <= 2 ? .good : todayAwakeCount <= 4 ? .fair : .poor
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    enum QualityRating {
        case good, fair, poor

        var color: Color {
            switch self {
            case .good: return .green
            case .fair: return .orange
            case .poor: return .red
            }
        }

        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .fair: return "exclamationmark.triangle.fill"
            case .poor: return "xmark.circle.fill"
            }
        }
    }

    private func qualityRow(title: String, description: String, rating: QualityRating) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rating.icon)
                .font(.title3)
                .foregroundStyle(rating.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sleep Session Model

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
            self.records = records.sorted { $0.startTime < $1.startTime }

            guard let first = self.records.first, let last = self.records.last else {
                date = Date()
                bedTime = Date()
                wakeTime = Date()
                totalSleep = 0
                deepSleep = 0
                lightSleep = 0
                remSleep = 0
                awakeTime = 0
                awakeCount = 0
                score = 0
                return
            }

            bedTime = first.startTime
            wakeTime = last.endTime
            date = Calendar.current.startOfDay(for: wakeTime)

            var deep: TimeInterval = 0
            var light: TimeInterval = 0
            var rem: TimeInterval = 0
            var awake: TimeInterval = 0
            var awakeSegments = 0

            for record in self.records {
                let duration = record.endTime.timeIntervalSince(record.startTime)
                switch record.sleepType {
                case .deep: deep += duration
                case .light: light += duration
                case .rem: rem += duration
                case .awake:
                    awake += duration
                    awakeSegments += 1
                }
            }

            deepSleep = deep
            lightSleep = light
            remSleep = rem
            awakeTime = awake
            awakeCount = awakeSegments
            totalSleep = deep + light + rem

            // Calculate sleep score
            score = Self.calculateSleepScore(
                totalSleep: totalSleep,
                deepSleep: deep,
                remSleep: rem,
                awakeTime: awake,
                awakeCount: awakeSegments
            )
        }

        static func calculateSleepScore(totalSleep: TimeInterval, deepSleep: TimeInterval, remSleep: TimeInterval, awakeTime _: TimeInterval, awakeCount: Int) -> Int {
            var score = 0

            // Duration score (40 points max)
            let hours = totalSleep / 3600
            if hours >= 7 && hours <= 9 {
                score += 40
            } else if hours >= 6 && hours < 7 {
                score += 30
            } else if hours >= 5 && hours < 6 {
                score += 20
            } else {
                score += 10
            }

            // Deep sleep percentage (30 points max)
            let deepPercentage = totalSleep > 0 ? (deepSleep / totalSleep) * 100 : 0
            if deepPercentage >= 20 && deepPercentage <= 25 {
                score += 30
            } else if deepPercentage >= 15 && deepPercentage < 20 {
                score += 20
            } else if deepPercentage >= 10 && deepPercentage < 15 {
                score += 10
            }

            // REM sleep percentage (15 points max)
            let remPercentage = totalSleep > 0 ? (remSleep / totalSleep) * 100 : 0
            if remPercentage >= 20 && remPercentage <= 25 {
                score += 15
            } else if remPercentage >= 15 && remPercentage < 20 {
                score += 10
            } else if remPercentage >= 10 && remPercentage < 15 {
                score += 5
            }

            // Sleep interruptions (15 points max)
            if awakeCount <= 1 {
                score += 15
            } else if awakeCount <= 3 {
                score += 10
            } else if awakeCount <= 5 {
                score += 5
            }

            return min(100, score)
        }
    }

    /// Group sleep records into sessions
    private func groupSleepSessions() -> [SleepSession] {
        var sessions: [SleepSession] = []
        var currentGroup: [SleepRecord] = []

        let sortedRecords = ring.sleepRecords.sorted { $0.startTime < $1.startTime }

        for record in sortedRecords {
            if currentGroup.isEmpty {
                currentGroup.append(record)
            } else if let last = currentGroup.last {
                // If gap is more than 3 hours, start new session
                let gap = record.startTime.timeIntervalSince(last.endTime)
                if gap > 3 * 3600 {
                    sessions.append(SleepSession(records: currentGroup))
                    currentGroup = [record]
                } else {
                    currentGroup.append(record)
                }
            }
        }

        if !currentGroup.isEmpty {
            sessions.append(SleepSession(records: currentGroup))
        }

        return sessions
    }
}

// MARK: - Helper Methods

extension SleepView {
    private var allSleepSessions: [SleepSession] {
        groupSleepSessions()
    }

    private var todaySleepSession: SleepSession? {
        sleepSessionForDate(Date())
    }

    private func sleepSessionForDate(_ date: Date) -> SleepSession? {
        allSleepSessions.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var filteredSleepSessions: [SleepSession] {
        let now = Date()
        let interval = Double(selectedRange.days) * 86400
        return allSleepSessions.filter {
            $0.date > now.addingTimeInterval(-interval)
        }
    }

    private var xAxisStride: Calendar.Component {
        selectedRange == .week ? .day : .weekOfYear
    }

    private var xAxisFormat: Date.FormatStyle {
        selectedRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day()
    }

    private var todaySleepScore: Int {
        todaySleepSession?.score ?? 0
    }

    private var todayTotalSleep: TimeInterval {
        todaySleepSession?.totalSleep ?? 0
    }

    private var todayDeepSleep: TimeInterval {
        todaySleepSession?.deepSleep ?? 0
    }

    private var todayLightSleep: TimeInterval {
        todaySleepSession?.lightSleep ?? 0
    }

    private var todayREMSleep: TimeInterval {
        todaySleepSession?.remSleep ?? 0
    }

    private var todayAwakeCount: Int {
        todaySleepSession?.awakeCount ?? 0
    }

    private var weeklyComparison: Int? {
        guard let todayScore = todaySleepSession?.score else { return nil }
        let weekSessions = filteredSleepSessions.prefix(7)
        guard !weekSessions.isEmpty else { return nil }
        let lastWeekAvg = weekSessions.map(\.score).reduce(0, +) / weekSessions.count
        return todayScore - lastWeekAvg
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
        let goalSleep: TimeInterval = 8 * 3600 // 8 hours
        let weekSessions = filteredSleepSessions.prefix(7)
        let totalSleep = weekSessions.map(\.totalSleep).reduce(0, +)
        let expectedSleep = goalSleep * Double(weekSessions.count)
        return max(0, expectedSleep - totalSleep)
    }

    private var sleepConsistency: Int {
        guard filteredSleepSessions.count >= 2 else { return 0 }
        let bedTimes = filteredSleepSessions.map { $0.bedTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) }
        let avgBedTime = bedTimes.reduce(0, +) / Double(bedTimes.count)
        let variance = bedTimes.map { pow($0 - avgBedTime, 2) }.reduce(0, +) / Double(bedTimes.count)
        let standardDeviation = sqrt(variance)

        // Lower deviation = higher consistency
        let hourDeviation = standardDeviation / 3600
        if hourDeviation < 1 { return 80 + Int((1 - hourDeviation) * 20) }
        else if hourDeviation < 2 { return 60 + Int((2 - hourDeviation) * 20) }
        else if hourDeviation < 3 { return 40 + Int((3 - hourDeviation) * 20) }
        else { return 40 }
    }

    private var deepSleepPercentage: Double {
        guard todayTotalSleep > 0 else { return 0 }
        return (todayDeepSleep / todayTotalSleep) * 100
    }

    private var sleepGoalText: String {
        let goal: TimeInterval = 8 * 3600
        let diff = todayTotalSleep - goal
        if abs(diff) < 1800 { return "On target" }
        else if diff > 0 { return "\(formatDuration(diff)) over goal" }
        else { return "\(formatDuration(-diff)) short of goal" }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - SleepChartKit Wrapper

struct SleepChartView: View {
    let records: [SleepRecord]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))

                // Sleep stages
                HStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                        let duration = record.endTime.timeIntervalSince(record.startTime)
                        let totalDuration = records.last!.endTime.timeIntervalSince(records.first!.startTime)
                        let width = geometry.size.width * CGFloat(duration / totalDuration)

                        Rectangle()
                            .fill(colorForSleepType(record.sleepType))
                            .frame(width: width)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 200)
        }
    }

    private func colorForSleepType(_ type: SleepRecord.SleepType) -> Color {
        switch type {
        case .deep: return .purple
        case .light: return .blue
        case .rem: return .green
        case .awake: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        SleepView()
            .environment(RingSessionManager())
    }
}
