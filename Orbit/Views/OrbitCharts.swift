// OrbitCharts.swift
// Reusable Swift Charts components — adapted from Swift Charts Examples (MIT License)
// Used across HeartRateView, SPO2View, StressView, SleepView

import Charts
import SwiftUI

// MARK: - Lollipop Chart
// Adapted from SingleLineLollipop.swift — line + interactive vertical rule callout

struct LollipopChart: View {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let label: String        // e.g. "72 BPM" or "97%"
    }

    let points: [Point]
    let color: Color
    let yLabel: String
    let yDomain: ClosedRange<Double>?
    let xStride: Calendar.Component
    let xFormat: Date.FormatStyle

    @State private var selected: Point?

    var body: some View {
        Chart(points) { pt in
            LineMark(
                x: .value("Time", pt.date),
                y: .value(yLabel, pt.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            if selected?.id == pt.id {
                PointMark(x: .value("Time", pt.date), y: .value(yLabel, pt.value))
                    .symbol {
                        Circle()
                            .strokeBorder(color, lineWidth: 2)
                            .background(Circle().fill(.background))
                            .frame(width: 12)
                    }
            } else {
                PointMark(x: .value("Time", pt.date), y: .value(yLabel, pt.value))
                    .symbol { Circle().fill(color.opacity(0.5)).frame(width: 5) }
            }
        }
        .applyYDomain(yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: xStride)) {
                AxisGridLine(); AxisValueLabel(format: xFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { v in
                            let hit = nearest(to: v.location, proxy: proxy, geo: geo)
                            selected = (selected?.id == hit?.id) ? nil : hit
                        }
                        .exclusively(before: DragGesture().onChanged { v in
                            selected = nearest(to: v.location, proxy: proxy, geo: geo)
                        })
                    )
            }
        }
        .chartBackground { proxy in
            GeometryReader { geo in
                if let sel = selected {
                    let xPos = (proxy.position(forX: sel.date) ?? 0) + geo[proxy.plotAreaFrame].origin.x
                    let lineH = geo[proxy.plotAreaFrame].maxY
                    let bW: CGFloat = 100
                    let bX = max(0, min(geo.size.width - bW, xPos - bW / 2))

                    Rectangle().fill(color.opacity(0.7)).frame(width: 2, height: lineH)
                        .position(x: xPos, y: lineH / 2)

                    VStack(spacing: 2) {
                        Text(sel.date, format: xFormat).font(.caption2).foregroundStyle(.secondary)
                        Text(sel.label).font(.callout.bold())
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 8).fill(.background)
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.7))
                    }
                    .frame(width: bW)
                    .offset(x: bX)
                }
            }
        }
    }

    private func nearest(to location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Point? {
        let rel = location.x - geo[proxy.plotAreaFrame].origin.x
        guard let date: Date = proxy.value(atX: rel) else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

// MARK: - Range + Lollipop Chart
// Adapted from HeartRateRangeChart.swift — capsule bars showing min/max range + interactive lollipop

struct RangeLollipopChart: View {
    struct Bucket: Identifiable {
        let id = UUID()
        let date: Date
        let min: Double
        let avg: Double
        let max: Double
        let unit: String
    }

    let buckets: [Bucket]
    let color: Color
    let yLabel: String

    @State private var selected: Bucket?

    var body: some View {
        Chart(buckets) { b in
            // Range bar (capsule) — min to max
            BarMark(
                x: .value("Date", b.date, unit: .day),
                yStart: .value("Min", b.min),
                yEnd: .value("Max", b.max),
                width: .fixed(10)
            )
            .clipShape(Capsule())
            .foregroundStyle(color.opacity(selected?.id == b.id ? 1.0 : 0.55).gradient)

            // Avg dot
            PointMark(x: .value("Date", b.date, unit: .day), y: .value("Avg", b.avg))
                .symbol {
                    Circle()
                        .fill(selected?.id == b.id ? Color.white : color)
                        .frame(width: selected?.id == b.id ? 10 : 7)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { v in
                            let hit = nearestBucket(to: v.location, proxy: proxy, geo: geo)
                            selected = (selected?.id == hit?.id) ? nil : hit
                        }
                        .exclusively(before: DragGesture().onChanged { v in
                            selected = nearestBucket(to: v.location, proxy: proxy, geo: geo)
                        })
                    )
            }
        }
        .chartBackground { proxy in
            GeometryReader { geo in
                if let sel = selected {
                    let interval = Calendar.current.dateInterval(of: .day, for: sel.date)!
                    let xPos = (proxy.position(forX: interval.start) ?? 0) + geo[proxy.plotAreaFrame].origin.x
                    let lineH = geo[proxy.plotAreaFrame].maxY
                    let bW: CGFloat = 110
                    let bX = max(0, min(geo.size.width - bW, xPos - bW / 2))

                    Rectangle().fill(color.opacity(0.8)).frame(width: 2, height: lineH)
                        .position(x: xPos, y: lineH / 2)

                    VStack(alignment: .center, spacing: 2) {
                        Text(sel.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("\(Int(sel.min))–\(Int(sel.max)) \(sel.unit)")
                            .font(.caption.bold())
                        Text("avg \(Int(sel.avg)) \(sel.unit)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 8).fill(.background)
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.7))
                    }
                    .frame(width: bW)
                    .offset(x: bX)
                }
            }
        }
    }

    private func nearestBucket(to location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Bucket? {
        let rel = location.x - geo[proxy.plotAreaFrame].origin.x
        guard let date: Date = proxy.value(atX: rel) else { return nil }
        return buckets.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

// MARK: - Single Bar with Threshold RuleMark
// Adapted from SingleBarThreshold.swift

struct ThresholdBarChart: View {
    struct Bar: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    let bars: [Bar]
    let threshold: Double
    let yLabel: String
    let belowColor: Color
    let aboveColor: Color
    let xStride: Calendar.Component
    let xFormat: Date.FormatStyle

    var body: some View {
        Chart {
            ForEach(bars) { b in
                BarMark(
                    x: .value("Date", b.date, unit: xStride),
                    y: .value(yLabel, b.value)
                )
                .foregroundStyle((b.value >= threshold ? aboveColor : belowColor).gradient)
                .cornerRadius(4)
            }

            RuleMark(y: .value("Goal", threshold))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(.orange)
                .annotation(position: .top, alignment: .leading) {
                    Text("\(Int(threshold))")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 6).fill(.background)
                            RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.7))
                        }
                        .padding(.bottom, 4)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xStride)) {
                AxisGridLine(); AxisValueLabel(format: xFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() }
        }
    }
}

// MARK: - TimeSheet Horizontal Bar Chart
// Adapted from TimeSheetBar.swift / EventChart

struct TimeSheetBarChart: View {
    struct Segment: Identifiable {
        let id = UUID()
        let category: String
        let start: Date
        let end: Date
        let color: Color
    }

    let segments: [Segment]
    let domainStart: Date
    let domainEnd: Date

    @State private var selected: Segment?

    var body: some View {
        Chart {
            ForEach(segments) { seg in
                Plot {
                    BarMark(
                        xStart: .value("Start", seg.start),
                        xEnd: .value("End", seg.end),
                        y: .value("Category", seg.category)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(seg.color.gradient)
                    .opacity(selected == nil || selected?.id == seg.id ? 1.0 : 0.4)

                    if let sel = selected, sel.id == seg.id {
                        RuleMark(x: .value("Mid", midDate(sel)))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                            .foregroundStyle(sel.color)
                            .annotation(position: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sel.start.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Text("→ " + sel.end.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Text(durationString(sel))
                                        .font(.caption.bold())
                                }
                                .padding(6)
                                .background {
                                    RoundedRectangle(cornerRadius: 6).fill(.background)
                                        .shadow(color: .black.opacity(0.1), radius: 4)
                                }
                            }
                    }
                }
                .accessibilityLabel(seg.category)
                .accessibilityValue("\(seg.start.formatted(date:.omitted,time:.shortened)) – \(seg.end.formatted(date:.omitted,time:.shortened))")
            }
        }
        .chartXScale(domain: domainStart...domainEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel() }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { loc in
                        if let date: Date = proxy.value(atX: loc.x - geo[proxy.plotAreaFrame].origin.x) {
                            let hit = segments.first { $0.start <= date && date <= $0.end }
                            selected = (hit?.id == selected?.id) ? nil : hit
                        }
                    }
            }
        }
    }

    private func midDate(_ s: Segment) -> Date {
        Date(timeIntervalSince1970: (s.start.timeIntervalSince1970 + s.end.timeIntervalSince1970) / 2)
    }

    private func durationString(_ s: Segment) -> String {
        let sec = s.end.timeIntervalSince(s.start)
        let h = Int(sec) / 3600; let m = Int(sec) % 3600 / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - ScreenTime-style stacked column + drill-down
// Adapted from ScreenTime.swift

struct ScreenTimeStyleChart: View {
    struct Item: Identifiable {
        let id = UUID()
        let date: Date          // start of day for week bars; start of hour for day bars
        let category: String
        let value: Double
        let color: Color
    }

    let weekItems: [Item]
    let hourItems: [Item]       // all hours; chart filters to selectedDate
    let average: Double
    let yFormatter: (Double) -> String

    @Binding var selectedDate: Date

    var body: some View {
        VStack(spacing: 0) {
            weekChart.frame(height: 130)
            Divider().padding(.vertical, 6)
            dayChart.frame(height: 90)
        }
    }

    // MARK: Week bars
    private var weekChart: some View {
        Chart {
            ForEach(weekItems) { item in
                let isSel = Calendar.current.isDate(item.date, inSameDayAs: selectedDate)
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(isSel ? item.color.gradient : Color.secondary.opacity(0.3).gradient)
                .cornerRadius(4)
            }
            RuleMark(y: .value("Average", average))
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("avg").font(.caption2).foregroundStyle(.green)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine(); AxisTick()
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { v in
                AxisGridLine()
                if let d = v.as(Double.self) { AxisValueLabel(yFormatter(d)) }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                        if let date: Date = proxy.value(atX: x) {
                            selectedDate = Calendar.current.startOfDay(for: date)
                        }
                    })
            }
        }
    }

    // MARK: Day (hourly) bars
    private var dayChart: some View {
        let dayItems = hourItems.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        let dayEnd   = dayStart.addingTimeInterval(86400)

        return Chart(dayItems) { item in
            BarMark(
                x: .value("Hour", item.date, unit: .hour),
                y: .value("Value", item.value)
            )
            .foregroundStyle(item.color.gradient)
            .cornerRadius(3)
        }
        .chartXScale(domain: dayStart...dayEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { v in
                AxisGridLine()
                if let d = v.as(Double.self) { AxisValueLabel(yFormatter(d)) }
            }
        }
    }
}

// MARK: - Chart modifier helper

extension View {
    @ViewBuilder
    func applyYDomain(_ domain: ClosedRange<Double>?) -> some View {
        if let d = domain { self.chartYScale(domain: d) } else { self }
    }
}
