//
//  Activityringview.swift
//  Orbit
//
//  Created by Daniele Rolli on 2/4/26.
//

import SwiftUI

extension Color {
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        return adjust(by: abs(percentage))
    }

    func darker(by percentage: CGFloat = 30.0) -> Color {
        return adjust(by: -1 * abs(percentage))
    }

    func adjust(by percentage: CGFloat = 30.0) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1.0
        #if canImport(UIKit)
            UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
            NSColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif
        return Color(red: min(red + percentage / 100, 1.0),
                     green: min(green + percentage / 100, 1.0),
                     blue: min(blue + percentage / 100, 1.0),
                     opacity: alpha)
    }
}

struct ActivityRingView: View {
    @Binding var progress: CGFloat

    var mainColor: Color = .red
    var lineWidth: CGFloat = 20

    var endColor: Color {
        mainColor.darker(by: 15.0)
    }

    var startColor: Color {
        mainColor.lighter(by: 15.0)
    }

    var backgroundColor: Color {
        return mainColor.opacity(0.15)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(backgroundColor, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [startColor, endColor]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .frame(width: lineWidth, height: lineWidth)
                    .foregroundColor(startColor)
                    .offset(y: -1 * (geo.size.height / 2))
            }
            .rotationEffect(overlapRotatation())
            .frame(idealWidth: 300, idealHeight: 300, alignment: .center)
            .animation(.spring(.smooth, blendDuration: 0.5), value: progress)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
    }

    func overlapRotatation() -> Angle {
        let overlapProgress = progress - 1.0
        let degrees = overlapProgress * 360.0
        return .degrees(-1 * degrees)
    }
}
