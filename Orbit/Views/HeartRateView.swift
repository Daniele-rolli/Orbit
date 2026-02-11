//
//  HeartRateView.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/28/26.
//

import SwiftUI
import Charts
import HealthKit

struct HeartRateView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .day
    @State private var isStreaming = false
    @State private var streamingTimer: Timer?
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
                liveHeartRateCard
                heartRateChartCard
                heartRateStatsCard
                restingHeartRateCard
                hrvCard

                if !isStreaming {
                    measureButton
                }
            }
            .padding()
        }
        .navigationTitle("Heart")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshHistoricalData()
        }
        .onDisappear {
            stopStreaming()
        }
    }

    private func refreshHistoricalData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

extension HeartRateView {
    private var liveHeartRateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEART RATE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(ring.realtimeHeartRate ?? 0)")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())

                        Text("BPM")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isStreaming ? .red : .gray.opacity(0.3))
                    .symbolEffect(.pulse, isActive: isStreaming)
            }

            HStack {
                Circle()
                    .fill(isStreaming ? .red : .gray)
                    .frame(width: 8, height: 8)

                Text(isStreaming ? "Live" : "Not recording")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isStreaming {
                    Spacer()
                    Text("Auto-stops in 1 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

extension HeartRateView {
    private var heartRateChartCard: some View {
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
                heartRateChart
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var heartRateChart: some View {
        Chart {
            ForEach(filteredSamples, id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.heartRate)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.heartRate)
                )
                .foregroundStyle(.red.opacity(0.15))
                .interpolationMethod(.catmullRom)
            }

            if let avg = averageHeartRate {
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(.red.opacity(0.3))
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

    private var filteredSamples: [HeartRateSample] {
        let now = Date()
        let interval = Double(selectedRange.days) * 86400
        return ring.heartRateSamples.filter {
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
        let values = filteredSamples.map(\.heartRate)
        guard let min = values.min(), let max = values.max() else {
            return 40...200
        }
        let padding = (max - min) / 5
        return (min - padding)...(max + padding)
    }

    private var averageHeartRate: Int? {
        let values = filteredSamples.map(\.heartRate)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }
}

extension HeartRateView {
    private var heartRateStatsCard: some View {
        HStack(spacing: 0) {
            statColumn("Low", value: filteredSamples.map(\.heartRate).min(), color: .blue)
            Divider().frame(height: 60)
            statColumn("Average", value: averageHeartRate, color: .orange)
            Divider().frame(height: 60)
            statColumn("High", value: filteredSamples.map(\.heartRate).max(), color: .red)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func statColumn(_ title: String, value: Int?, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("BPM")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension HeartRateView {
    private var restingHeartRateCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("RESTING")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("--")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))

                    Text("BPM")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text("No data today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "bed.double.fill")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

extension HeartRateView {
    private var hrvCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("HEART RATE VARIABILITY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(ring.hrvSamples.last.map { "\($0.hrvValue)" } ?? "--")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))

                    Text("ms")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text("SDNN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(.cyan)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

extension HeartRateView {
    private var measureButton: some View {
        Button {
            startStreaming()
        } label: {
            HStack {
                Image(systemName: "heart.fill")
                Text("Measure Heart Rate")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red)
            )
        }
    }
}

extension HeartRateView {
    private func startStreaming() {
        isStreaming = true
        ring.startRealtimeHeartRate()

        streamingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
            stopStreaming()
        }
    }

    private func stopStreaming() {
        guard isStreaming else { return }
        isStreaming = false
        ring.stopRealtimeHeartRate()
        streamingTimer?.invalidate()
        streamingTimer = nil
    }
}

#Preview {
    NavigationStack {
        HeartRateView()
            .environment(RingSessionManager())
    }
}
