// SPO2View.swift — Orbit

import Charts
import SwiftUI

struct SPO2View: View {
    @Environment(RingSessionManager.self) var ring
    @State private var selectedRange: TimeRange = .week
    @State private var isLoading = false
    @State private var historicalSamples: [SpO2Sample] = []

    enum TimeRange: String, CaseIterable {
        case day = "Day", week = "Week", month = "Month"
        var days: Int { switch self { case .day: 1; case .week: 7; case .month: 30 } }
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
        historicalSamples = (try? await ring.storageManager.loadSpO2()) ?? []
        isLoading = false
    }
}

// MARK: - Latest Reading Card

extension SPO2View {
    private var latestSpO2Card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BLOOD OXYGEN")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(latestSpO2.map(String.init) ?? "--")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "lungs.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(statusColor(latestSpO2))
            }
            if let latest = historicalSamples.last {
                HStack(spacing: 6) {
                    if let v = latestSpO2 {
                        Image(systemName: statusIcon(v)); Text(statusText(v))
                    }
                    Spacer()
                    Image(systemName: "clock").font(.caption2)
                    Text(latest.timestamp.formatted(.relative(presentation: .named))).font(.caption)
                }
                .font(.caption).foregroundStyle(statusColor(latestSpO2))
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(Capsule().fill(statusColor(latestSpO2).opacity(0.1)))
            } else {
                Text("No recorded data — sync your ring to populate history")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var latestSpO2: Int? { historicalSamples.last?.spO2 }
}

// MARK: - SpO2 Chart Card (Range + Lollipop)

extension SPO2View {
    private var spO2ChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trends").font(.title3).fontWeight(.semibold)
                    if let lo = filteredSamples.map(\.spO2).min(),
                       let hi = filteredSamples.map(\.spO2).max() {
                        Text("\(lo)–\(hi)%")
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
                emptyState(icon: "chart.line.uptrend.xyaxis", message: "No data for this period")
            } else if selectedRange == .day {
                // Day: lollipop over individual readings, normal-range band behind
                Chart {
                    // Normal range band
                    RectangleMark(yStart: .value("Lo", 95), yEnd: .value("Hi", 100))
                        .foregroundStyle(.green.opacity(0.07))
                }
                .chartOverlay { _ in
                    LollipopChart(
                        points: filteredSamples.map {
                            LollipopChart.Point(date: $0.timestamp,
                                               value: Double($0.spO2),
                                               label: "\($0.spO2)%")
                        },
                        color: .cyan, yLabel: "%",
                        yDomain: spO2Domain, xStride: .hour, xFormat: .dateTime.hour()
                    )
                }
                .frame(height: 220)
            } else {
                // Week/Month: range capsules + lollipop callout
                ZStack {
                    // Normal-range rule band (purely decorative)
                    Chart {
                        RectangleMark(yStart: .value("Lo", 95), yEnd: .value("Hi", 100))
                            .foregroundStyle(.green.opacity(0.07))
                    }
                    .allowsHitTesting(false)
                    .chartYScale(domain: spO2DomainDouble)

                    RangeLollipopChart(buckets: spO2Buckets, color: .cyan, yLabel: "%")
                }
                .frame(height: 220)
            }

            // Normal-range legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(.green.opacity(0.3)).frame(width: 16, height: 8)
                Text("Normal range 95–100%").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var spO2Buckets: [RangeLollipopChart.Bucket] {
        let grouped = Dictionary(grouping: filteredSamples) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return grouped.map { (day, samples) in
            let vals = samples.map { Double($0.spO2) }
            return RangeLollipopChart.Bucket(
                date: day, min: vals.min() ?? 0,
                avg: vals.reduce(0, +) / Double(vals.count),
                max: vals.max() ?? 0, unit: "%"
            )
        }.sorted { $0.date < $1.date }
    }

    private var spO2Domain: ClosedRange<Double> {
        let vals = filteredSamples.map { Double($0.spO2) }
        guard let lo = vals.min(), let hi = vals.max() else { return 85...100 }
        let pad = max(2.0, (hi - lo) / 5)
        return max(85, lo - pad)...min(100, hi + pad)
    }

    private var spO2DomainDouble: ClosedRange<Double> { spO2Domain }
}

// MARK: - Stats Card

extension SPO2View {
    private var spO2StatsCard: some View {
        HStack(spacing: 0) {
            statCol("Low",     value: filteredSamples.map(\.spO2).min(), color: .orange)
            Divider().frame(height: 60)
            statCol("Average", value: averageSpO2,                       color: .cyan)
            Divider().frame(height: 60)
            statCol("High",    value: filteredSamples.map(\.spO2).max(), color: .green)
        }
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func statCol(_ title: String, value: Int?, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(color)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text("%").font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var averageSpO2: Int? {
        let v = filteredSamples.map(\.spO2); guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / v.count
    }
}

// MARK: - Zones Card

extension SPO2View {
    private var oxygenZonesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Understanding Your Levels").font(.headline)
            VStack(spacing: 12) {
                zoneRow(range: "95–100%", label: "Normal",   description: "Healthy oxygen saturation",  color: .green)
                zoneRow(range: "90–94%",  label: "Low",      description: "May indicate concern",        color: .orange)
                zoneRow(range: "< 90%",   label: "Very Low", description: "Seek medical attention",      color: .red)
            }
            Text("Consult a healthcare professional if you have concerns about your oxygen levels.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func zoneRow(range: String, label: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(range).font(.subheadline).fontWeight(.semibold)
                    Text("•").foregroundStyle(.secondary)
                    Text(label).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Shared helpers

extension SPO2View {
    private var filteredSamples: [SpO2Sample] {
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.days) * 86400)
        return historicalSamples.filter { $0.timestamp > cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    private func statusColor(_ v: Int?) -> Color {
        guard let v else { return .gray }
        return v >= 95 ? .cyan : v >= 90 ? .orange : .red
    }
    private func statusIcon(_ v: Int) -> String {
        v >= 95 ? "checkmark.circle.fill" : v >= 90 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill"
    }
    private func statusText(_ v: Int) -> String {
        v >= 95 ? "Normal" : v >= 90 ? "Low" : "Very Low"
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
    NavigationStack { SPO2View().environment(RingSessionManager()) }
}
