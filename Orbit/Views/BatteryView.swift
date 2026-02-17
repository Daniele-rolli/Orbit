//
//  BatteryView.swift
//  Orbit
//
//  Created by Cyril Zakka on 3/17/25.
//

import SwiftUI

struct BatteryView: View {
    @State var isCharging: Bool = false
    var batteryLevel: Int

    var color: Color {
        switch batteryLevel {
        case 0 ... 20:
            return Color.red
        case 20 ... 50:
            return Color.yellow
        case 50 ... 100:
            return Color.green
        default:
            return Color.clear
        }
    }

    var percent: Double {
        max(0.0, min(1.0, Double(batteryLevel) / 100.0))
    }

    var body: some View {
        if isCharging {
            Image(systemName: "battery.100percent.bolt")
                .symbolRenderingMode(.palette)
                .renderingMode(.original)
                .foregroundStyle(
                    .primary,
                    .primary,
                    .linearGradient(
                        stops: [
                            Gradient.Stop(color: color, location: 0),
                            Gradient.Stop(color: color, location: percent),
                            Gradient.Stop(color: .clear, location: percent),
                            Gradient.Stop(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        } else {
            Image(systemName: "battery.100percent")
                .symbolRenderingMode(.palette)
                .foregroundStyle(LinearGradient(stops: [
                    Gradient.Stop(color: color, location: 0),
                    Gradient.Stop(color: color, location: percent),
                    Gradient.Stop(color: .clear, location: percent),
                    Gradient.Stop(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing), .primary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BatteryView(isCharging: true, batteryLevel: 10) // Red
        BatteryView(isCharging: true, batteryLevel: 50) // Yellow
        BatteryView(isCharging: true, batteryLevel: 80) // Green
        BatteryView(isCharging: true, batteryLevel: 100) // Green
        BatteryView(isCharging: false, batteryLevel: 10) // Red
        BatteryView(isCharging: false, batteryLevel: 50) // Yellow
        BatteryView(isCharging: false, batteryLevel: 100) // Green
    }
}
