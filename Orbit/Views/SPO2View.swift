//
//  SPO2View.swift
//  Orbit
//
//  Created by Cyril Zakka on 3/17/25.
//

import Charts
import SwiftUI

struct SPO2View: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .day
    @State private var isRefreshing = false

    enum TimeRange: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                latestSpO2Card
                spO2ChartCard
                spO2StatsCard
                oxygenZonesCard
            }
            .padding()
        }
        .navigationTitle("Oxygen")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshHistoricalData()
        }
    }

    private func refreshHistoricalData() async {
        isRefreshing = true
        // Simulated network/health data fetch
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Subviews

extension SPO2View {
    private var latestSpO2Card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LATEST READING")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(ring.realtimeSpO2 ?? 0)")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))

                        Text("%")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "lungs.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(statusColor(ring.realtimeSpO2))
            }

            if let currentSpO2 = ring.realtimeSpO2 {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(currentSpO2))
                        .font(.caption)
                    Text(statusText(currentSpO2))
                        .font(.caption)
                }
                .foregroundStyle(statusColor(currentSpO2))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(statusColor(currentSpO2).opacity(0.1))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var spO2ChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trends")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if filteredSamples.isEmpty {
                emptyStateView
            } else {
                spO2Chart
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var spO2Chart: some View {
        Chart {
            ForEach(filteredSamples, id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("SpO2", sample.spO2)
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("SpO2", sample.spO2)
                )
                .foregroundStyle(.cyan.opacity(0.15))
                .interpolationMethod(.catmullRom)
            }

            // Normal range indicator (95-100%)
            RectangleMark(
                yStart: .value("Normal Start", 95),
                yEnd: .value("Normal End", 100)
            )
            .foregroundStyle(.green.opacity(0.05))

            if let avg = averageSpO2 {
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(.cyan.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
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
        .chartYScale(domain: yAxisDomain)
        .frame(height: 200)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Data Available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Pull down to refresh historical data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private var spO2StatsCard: some View {
        HStack(spacing: 0) {
            statColumn("Low", value: filteredSamples.map(\.spO2).min(), color: .orange)
            Divider().frame(height: 60)
            statColumn("Average", value: averageSpO2, color: .cyan)
            Divider().frame(height: 60)
            statColumn("High", value: filteredSamples.map(\.spO2).max(), color: .green)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var oxygenZonesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Understanding Your Levels")
                .font(.headline)

            VStack(spacing: 12) {
                zoneRow(range: "95-100%", label: "Normal", description: "Healthy oxygen saturation", color: .green)
                zoneRow(range: "90-94%", label: "Low", description: "May indicate concern", color: .orange)
                zoneRow(range: "Below 90%", label: "Very Low", description: "Seek medical attention", color: .red)
            }

            Text("Note: Consult a healthcare professional if you have concerns about your oxygen levels.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Computed Properties & Helpers

extension SPO2View {
    private var filteredSamples: [SpO2Sample] {
        let now = Date()
        let interval = Double(selectedRange.days) * 86400
        return ring.spO2Samples.filter {
            $0.timestamp > now.addingTimeInterval(-interval)
        }
    }

    private var xAxisStride: Calendar.Component {
        switch selectedRange {
        case .day: return .hour
        case .week, .month: return .day
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        }
    }

    private var yAxisDomain: ClosedRange<Int> {
        let values = filteredSamples.map(\.spO2)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 85 ... 100
        }
        let padding = Swift.max(2, (maxValue - minValue) / 5)
        return Swift.max(85, minValue - padding) ... Swift.min(100, maxValue + padding)
    }

    private var averageSpO2: Int? {
        let values = filteredSamples.map(\.spO2)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private func statusColor(_ spO2: Int?) -> Color {
        guard let spO2 else { return .gray }
        switch spO2 {
        case 95 ... 100: return .cyan
        case 90 ..< 95: return .orange
        default: return .red
        }
    }

    private func statusIcon(_ spO2: Int) -> String {
        switch spO2 {
        case 95 ... 100: return "checkmark.circle.fill"
        case 90 ..< 95: return "exclamationmark.triangle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private func statusText(_ spO2: Int) -> String {
        switch spO2 {
        case 95 ... 100: return "Normal"
        case 90 ..< 95: return "Low"
        default: return "Very Low"
        }
    }

    private func statColumn(_ title: String, value: Int?, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func zoneRow(range: String, label: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(range)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        SPO2View()
            .environment(RingSessionManager())
    }
}
