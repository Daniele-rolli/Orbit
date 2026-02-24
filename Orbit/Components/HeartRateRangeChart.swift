import SwiftUI
import Charts

struct HeartRateRangeData: Identifiable {
    let id = UUID()
    let date: Date
    let min: Int
    let max: Int
    var average: Int { (min + max) / 2 }
}

struct HeartRateRangeChart: View {
    // Inputs
    let data: [HeartRateRangeData]
    let title: String
    let isOverview: Bool
    
    // Customization
    @State private var barWidth = 10.0
    @State private var chartColor: Color = .red

    var body: some View {
        if isOverview {
            chart
        } else {
            List {
                Section(header: header) {
                    chart
                }
                customisation
            }
            .navigationTitle(title)
        }
    }

    private var chart: some View {
        Chart(data) { dataPoint in
            BarMark(
                x: .value("Day", dataPoint.date, unit: .day),
                yStart: .value("BPM Min", dataPoint.min),
                yEnd: .value("BPM Max", dataPoint.max),
                width: .fixed(isOverview ? 8 : barWidth)
            )
            .clipShape(Capsule())
            .foregroundStyle(chartColor.gradient)
            .accessibilityLabel(dataPoint.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue("\(dataPoint.min) to \(dataPoint.max) BPM")
            .accessibilityHidden(isOverview)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisTick()
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis(isOverview ? .hidden : .automatic)
        .chartXAxis(isOverview ? .hidden : .automatic)
        .frame(height: isOverview ? 150 : 300)
        .accessibilityChartDescriptor(self)
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text("Range")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let first = data.first, let last = data.last {
                Text("\(data.map(\.min).min() ?? 0)-\(data.map(\.max).max() ?? 0) ")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                + Text("BPM").foregroundColor(.secondary)
                
                Text("\(first.date, format: .dateTime.month().day()) - \(last.date, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var customisation: some View {
        Section("Appearance") {
            VStack(alignment: .leading) {
                Text("Bar Width: \(barWidth, specifier: "%.0f")")
                Slider(value: $barWidth, in: 5...25)
            }
            ColorPicker("Theme Color", selection: $chartColor)
        }
    }
}

extension HeartRateRangeChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let minVal = data.map(\.min).min() ?? 0
        let maxVal = data.max { $0.max < $1.max }?.max ?? 0
        
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Day",
            categoryOrder: data.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Heart Rate",
            range: Double(minVal)...Double(maxVal),
            gridlinePositions: []
        ) { value in "\(Int(value)) BPM" }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: data.map {
                .init(x: $0.date.formatted(date: .abbreviated, time: .omitted),
                      y: Double($0.average),
                      label: "Min: \($0.min), Max: \($0.max) BPM")
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: "Weekly heart rate range showing daily minimums and maximums.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
