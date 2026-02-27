// StressView.swift — Orbit

import Charts
import SwiftUI

struct StressView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .day
    @State private var isLoading = false
    @State private var historicalSamples: [StressSample] = []

    enum TimeRange: String, CaseIterable {
        case day = "Day", week = "Week", month = "Month"
        var days: Int { switch self { case .day: 1; case .week: 7; case .month: 30 } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                currentStressCard
                stressRangeCard
                stressBreakdownCard
                stressLollipopCard
                stressInsightsCard
            }
            .padding()
        }
        .navigationTitle("Stress")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await loadFromStorage() }
        .task { await loadFromStorage() }
        .overlay {
            if isLoading {
                ProgressView("Loading…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func loadFromStorage() async {
        isLoading = true
        historicalSamples = (try? await ring.storageManager.loadStress()) ?? []
        isLoading = false
    }
}

// MARK: - Current Stress Card (keep the wheel)

extension StressView {
    private var currentStressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STRESS LEVEL")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(latestLevel.map(String.init) ?? "--")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                            .foregroundStyle(stressColor(latestLevel ?? 0))
                        if let level = latestLevel {
                            Text(RingConstants.stressLabel(for: level))
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(stressColor(level))
                        }
                    }
                }
                Spacer()
                // Gauge wheel — retained as requested
                ZStack {
                    Circle()
                        .stroke(stressColor(latestLevel ?? 0).opacity(0.15), lineWidth: 12)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(latestLevel ?? 0) / 100.0)
                        .stroke(stressColor(latestLevel ?? 0),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28))
                        .foregroundStyle(stressColor(latestLevel ?? 0))
                }
            }

            if let latest = historicalSamples.last {
                Label("Last recorded \(latest.timestamp.formatted(.relative(presentation: .named)))",
                      systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No stress data — sync your ring to populate history")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Zone strip with indicator
            HStack(spacing: 0) {
                zoneChip("Relaxed", color: .mint)
                zoneChip("Normal",  color: .green)
                zoneChip("Medium",  color: .orange)
                zoneChip("High",    color: .red)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if let level = latestLevel {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4).fill(.white)
                            .frame(width: 3, height: 28)
                            .offset(x: geo.size.width * CGFloat(level) / 100.0 - 1.5,
                                    y: (geo.size.height - 28) / 2)
                    }
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func zoneChip(_ label: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.25)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).frame(height: 28)
    }

    private var latestLevel: Int? { historicalSamples.last?.stressLevel }
}

// MARK: - Today's Range Card

extension StressView {
    private var stressRangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Activity").font(.title3).fontWeight(.semibold)
                    if let lo = todayStressBuckets.map(\.min).min(),
                       let hi = todayStressBuckets.map(\.max).max() {
                        Text("\(Int(lo))–\(Int(hi))")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                    }
                }
                Spacer()
            }

            if todayStressBuckets.isEmpty {
                emptyState(icon: "waveform.path.ecg.rectangle", message: "No stress activity for today")
            } else {
                RangeLollipopChart(buckets: todayStressBuckets, color: .purple, yLabel: "Stress")
                    .frame(height: 220)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var todayStressBuckets: [RangeLollipopChart.Bucket] {
        let sorted = historicalSamples
            .filter { Calendar.current.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        let grouped = Dictionary(grouping: sorted) {
            Calendar.current.dateInterval(of: .hour, for: $0.timestamp)?.start ?? $0.timestamp
        }

        return grouped.map { (hour, samples) in
            let vals = samples.map { Double($0.stressLevel) }
            return RangeLollipopChart.Bucket(
                date: hour,
                min: vals.min() ?? 0,
                avg: vals.reduce(0, +) / Double(vals.count),
                max: vals.max() ?? 0,
                unit: ""
            )
        }.sorted { $0.date < $1.date }
    }

}

// MARK: - Lollipop Trend Card (replaces old trend card)

extension StressView {
    private var stressLollipopCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trend").font(.title3).fontWeight(.semibold)
                Spacer()
                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 200)
            }

            if filteredSamples.isEmpty {
                emptyState(icon: "waveform.path", message: "No trend data for this period")
            } else if selectedRange == .day {
                ZStack {
                    Chart {
                        RuleMark(y: .value("Relaxed", 30))
                            .foregroundStyle(.green.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        RuleMark(y: .value("Medium", 60))
                            .foregroundStyle(.orange.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        RuleMark(y: .value("High", 80))
                            .foregroundStyle(.red.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartYScale(domain: 0.0...100.0)
                    .allowsHitTesting(false)

                    LollipopChart(
                        points: filteredSamples.map {
                            LollipopChart.Point(
                                date: $0.timestamp,
                                value: Double($0.stressLevel),
                                label: "\($0.stressLevel) — \(RingConstants.stressLabel(for: $0.stressLevel))"
                            )
                        },
                        color: .purple,
                        yLabel: "Stress",
                        yDomain: 0.0...100.0,
                        xStride: .hour,
                        xFormat: .dateTime.hour()
                    )
                }
                .frame(height: 200)
            } else {
                RangeLollipopChart(buckets: trendBuckets, color: .purple, yLabel: "Stress")
                    .frame(height: 220)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var trendBuckets: [RangeLollipopChart.Bucket] {
        let grouped = Dictionary(grouping: filteredSamples) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }

        return grouped.map { day, samples in
            let values = samples.map { Double($0.stressLevel) }
            return RangeLollipopChart.Bucket(
                date: day,
                min: values.min() ?? 0,
                avg: values.reduce(0, +) / Double(values.count),
                max: values.max() ?? 0,
                unit: ""
            )
        }
        .sorted { $0.date < $1.date }
    }
}

// MARK: - Breakdown Card

extension StressView {
    private var stressBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Time in Zone").font(.title3).fontWeight(.semibold)
                Spacer()
                Text("\(filteredSamples.count) samples")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredSamples.isEmpty {
                emptyState(icon: "chart.pie", message: "No data for this period")
            } else {
                let zones = zoneBreakdown(filteredSamples)
                HStack(spacing: 10) {
                    summaryPill(title: "Dominant", value: dominantZoneName(for: zones), color: dominantZoneColor(for: zones))
                    summaryPill(title: "High", value: "\(highZonePercent(for: zones))%", color: .red)
                }

                VStack(spacing: 10) {
                    zoneBar("Relaxed", value: zones.relaxed, total: filteredSamples.count, color: .mint)
                    zoneBar("Normal",  value: zones.normal,  total: filteredSamples.count, color: .green)
                    zoneBar("Medium",  value: zones.medium,  total: filteredSamples.count, color: .orange)
                    zoneBar("High",    value: zones.high,    total: filteredSamples.count, color: .red)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func summaryPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
    }

    private func zoneBar(_ label: String, value: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(value) / Double(total) : 0
        return HStack(spacing: 12) {
            Text(label).font(.subheadline).fontWeight(.medium).frame(width: 66, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * pct, height: 8)
                }
            }.frame(height: 8)
            Text("\(Int(pct * 100))%")
                .font(.caption).fontWeight(.semibold).foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
            Text("\(value)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private struct ZoneBreakdown { var relaxed = 0, normal = 0, medium = 0, high = 0 }
    private func zoneBreakdown(_ samples: [StressSample]) -> ZoneBreakdown {
        var z = ZoneBreakdown()
        for s in samples {
            switch s.stressLevel {
            case ..<30:   z.relaxed += 1
            case 30..<60: z.normal  += 1
            case 60..<80: z.medium  += 1
            default:      z.high    += 1
            }
        }
        return z
    }

    private func dominantZoneName(for zones: ZoneBreakdown) -> String {
        let entries: [(String, Int)] = [
            ("Relaxed", zones.relaxed),
            ("Normal", zones.normal),
            ("Medium", zones.medium),
            ("High", zones.high)
        ]
        return entries.max(by: { $0.1 < $1.1 })?.0 ?? "None"
    }

    private func dominantZoneColor(for zones: ZoneBreakdown) -> Color {
        switch dominantZoneName(for: zones) {
        case "Relaxed": return .mint
        case "Normal": return .green
        case "Medium": return .orange
        case "High": return .red
        default: return .secondary
        }
    }

    private func highZonePercent(for zones: ZoneBreakdown) -> Int {
        let total = zones.relaxed + zones.normal + zones.medium + zones.high
        guard total > 0 else { return 0 }
        return Int((Double(zones.high) / Double(total)) * 100)
    }
}

// MARK: - Insights Card

extension StressView {
    private var stressInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights").font(.title3).fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                insightCell(title: "Avg Today",     value: avgToday.map(String.init) ?? "--",  unit: "",       icon: "gauge.medium",              color: stressColor(avgToday ?? 0))
                insightCell(title: "Peak Today",    value: peakToday.map(String.init) ?? "--", unit: "",       icon: "arrow.up.circle.fill",       color: .red)
                insightCell(title: "Relaxed Time",  value: "\(relaxedPctToday)%",              unit: "today",  icon: "leaf.fill",                  color: .mint)
                insightCell(title: "High Stress",   value: "\(highPctToday)%",                 unit: "today",  icon: "exclamationmark.triangle.fill", color: highPctToday > 20 ? .red : .orange)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func insightCell(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon).font(.title3).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded))
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }
}

// MARK: - Shared helpers

extension StressView {
    func stressColor(_ level: Int) -> Color {
        switch level {
        case ..<30:   return .mint
        case 30..<60: return .green
        case 60..<80: return .orange
        default:      return .red
        }
    }

    private var filteredSamples: [StressSample] {
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.days) * 86400)
        return historicalSamples.filter { $0.timestamp > cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    private var todaySamples: [StressSample] {
        historicalSamples.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    private var avgToday: Int? {
        let s = todaySamples; guard !s.isEmpty else { return nil }
        return s.map(\.stressLevel).reduce(0, +) / s.count
    }
    private var peakToday: Int? { todaySamples.map(\.stressLevel).max() }
    private var relaxedPctToday: Int {
        guard !todaySamples.isEmpty else { return 0 }
        return Int(Double(todaySamples.filter { $0.stressLevel < 30 }.count) / Double(todaySamples.count) * 100)
    }
    private var highPctToday: Int {
        guard !todaySamples.isEmpty else { return 0 }
        return Int(Double(todaySamples.filter { $0.stressLevel >= 80 }.count) / Double(todaySamples.count) * 100)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary.opacity(0.4))
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).frame(height: 120)
    }
}

#Preview {
    NavigationStack { StressView().environment(RingSessionManager()) }
}
