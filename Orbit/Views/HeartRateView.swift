// HeartRateView.swift — Orbit

import Charts
import SwiftUI

struct HeartRateView: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .week
    @State private var isLoading = false
    @State private var historicalSamples: [HeartRateSample] = []
    @State private var historicalHRV: [HRVSample] = []

    enum TimeRange: String, CaseIterable {
        case day = "Day", week = "Week", month = "Month"
        var days: Int { switch self { case .day: 1; case .week: 7; case .month: 30 } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                latestReadingCard
                heartRateRangeCard
                heartRateStatsCard
                restingHeartRateCard
                hrvCard
            }
            .padding()
        }
        .navigationTitle("Heart")
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
        do {
            historicalSamples = try await ring.storageManager.loadHeartRate()
            historicalHRV     = try await ring.storageManager.loadHRV()
        } catch { }
        isLoading = false
    }
}

// MARK: - Latest Reading Card

extension HeartRateView {
    private var latestReadingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEART RATE")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(latestHeartRate.map(String.init) ?? "--")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("BPM")
                            .font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(latestHeartRate != nil ? .red : .gray.opacity(0.3))
            }
            if let latest = historicalSamples.last {
                Label("Last recorded \(latest.timestamp.formatted(.relative(presentation: .named)))",
                      systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No recorded data — sync your ring to populate history")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var latestHeartRate: Int? {
        ring.latestMeasuredHeartRate ?? historicalSamples.last?.heartRate
    }
}

// MARK: - Heart Rate Range Chart Card

extension HeartRateView {
    private var heartRateRangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Range").font(.title3).fontWeight(.semibold)
                    if let lo = filteredSamples.map(\.heartRate).min(),
                       let hi = filteredSamples.map(\.heartRate).max() {
                        Text("\(lo)–\(hi) BPM")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                    }
                }
                Spacer()
                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 200)
            }

            if filteredSamples.isEmpty {
                emptyState(icon: "heart.text.square", message: "No data for this period")
            } else if selectedRange == .day {
                // Day: individual readings as lollipop line
                LollipopChart(
                    points: filteredSamples.map {
                        LollipopChart.Point(date: $0.timestamp,
                                           value: Double($0.heartRate),
                                           label: "\($0.heartRate) BPM")
                    },
                    color: .red, yLabel: "BPM",
                    yDomain: hrDomain, xStride: .hour, xFormat: .dateTime.hour()
                )
                .frame(height: 220)
            } else {
                // Week/Month: daily range capsules with lollipop callout
                RangeLollipopChart(buckets: hrBuckets, color: .red, yLabel: "BPM")
                    .frame(height: 220)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var hrBuckets: [RangeLollipopChart.Bucket] {
        let grouped = Dictionary(grouping: filteredSamples) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return grouped.map { (day, samples) in
            let vals = samples.map { Double($0.heartRate) }
            return RangeLollipopChart.Bucket(
                date: day, min: vals.min() ?? 0,
                avg: vals.reduce(0, +) / Double(vals.count),
                max: vals.max() ?? 0, unit: "BPM"
            )
        }.sorted { $0.date < $1.date }
    }

    private var hrDomain: ClosedRange<Double> {
        let vals = filteredSamples.map { Double($0.heartRate) }
        guard let lo = vals.min(), let hi = vals.max() else { return 40...200 }
        let pad = max(5.0, (hi - lo) / 5); return (lo - pad)...(hi + pad)
    }
}

// MARK: - Stats Card

extension HeartRateView {
    private var heartRateStatsCard: some View {
        HStack(spacing: 0) {
            statCol("Low",     value: filteredSamples.map(\.heartRate).min(), color: .blue)
            Divider().frame(height: 60)
            statCol("Average", value: averageHeartRate,                       color: .orange)
            Divider().frame(height: 60)
            statCol("High",    value: filteredSamples.map(\.heartRate).max(), color: .red)
        }
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func statCol(_ title: String, value: Int?, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(color)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text("BPM").font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var averageHeartRate: Int? {
        let v = filteredSamples.map(\.heartRate); guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / v.count
    }
}

// MARK: - Resting HR Card

extension HeartRateView {
    private var restingHeartRateCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("RESTING").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(restingHeartRate.map(String.init) ?? "--")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text("BPM").font(.callout).fontWeight(.medium).foregroundStyle(.secondary)
                }
                Text(restingHeartRate != nil ? "Lowest in past 24 h" : "No data in past 24 h")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bed.double.fill").font(.system(size: 36)).foregroundStyle(.indigo)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var restingHeartRate: Int? {
        historicalSamples
            .filter { $0.timestamp > Date().addingTimeInterval(-86400) }
            .map(\.heartRate).min()
    }
}

// MARK: - HRV Card (Range + Lollipop)

extension HeartRateView {
    private var hrvCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HRV").font(.title3).fontWeight(.semibold)
                    if let latest = historicalHRV.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(latest.hrvValue)")
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                            Text("ms").font(.callout).fontWeight(.medium).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "waveform.path.ecg").font(.system(size: 30)).foregroundStyle(.cyan)
            }
            Text("SDNN — heart rate variability").font(.caption).foregroundStyle(.secondary)

            if filteredHRV.isEmpty {
                emptyState(icon: "waveform", message: "No HRV data for this period")
            } else if selectedRange == .day {
                LollipopChart(
                    points: filteredHRV.map {
                        LollipopChart.Point(date: $0.timestamp,
                                           value: Double($0.hrvValue),
                                           label: "\($0.hrvValue) ms")
                    },
                    color: .cyan, yLabel: "ms",
                    yDomain: nil, xStride: .hour, xFormat: .dateTime.hour()
                )
                .frame(height: 180)
            } else {
                RangeLollipopChart(buckets: hrvBuckets, color: .cyan, yLabel: "ms")
                    .frame(height: 180)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var filteredHRV: [HRVSample] {
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.days) * 86400)
        return historicalHRV.filter { $0.timestamp > cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    private var hrvBuckets: [RangeLollipopChart.Bucket] {
        let grouped = Dictionary(grouping: filteredHRV) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return grouped.map { (day, samples) in
            let vals = samples.map { Double($0.hrvValue) }
            return RangeLollipopChart.Bucket(
                date: day, min: vals.min() ?? 0,
                avg: vals.reduce(0, +) / Double(vals.count),
                max: vals.max() ?? 0, unit: "ms"
            )
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Shared helpers

extension HeartRateView {
    private var filteredSamples: [HeartRateSample] {
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.days) * 86400)
        return historicalSamples.filter { $0.timestamp > cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary.opacity(0.4))
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).frame(height: 180)
    }
}

#Preview {
    NavigationStack { HeartRateView().environment(RingSessionManager()) }
}
