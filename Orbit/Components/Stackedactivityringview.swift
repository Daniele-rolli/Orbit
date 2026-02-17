//
//  Stackedactivityringview.swift
//  Orbit
//
//  Created by Daniele Rolli on 2/4/26.
//

import SwiftUI

struct StackedActivityRingViewConfig {
    var lineWidth: CGFloat = 15.0
    var outterRingColor: Color = .green
    var middleRingColor: Color = .blue
    var innerRingColor: Color = .red
}

struct StackedActivityRingView: View {
    @Binding var outterRingValue: CGFloat
    @Binding var middleRingValue: CGFloat
    @Binding var innerRingValue: CGFloat

    var config: StackedActivityRingViewConfig = .init()
    var width: CGFloat = 80.0
    var height: CGFloat = 80.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ActivityRingView(progress: $outterRingValue, mainColor: config.outterRingColor, lineWidth: config.lineWidth)
                    .frame(width: geo.size.width, height: geo.size.height)
                ActivityRingView(progress: $middleRingValue, mainColor: config.middleRingColor, lineWidth: config.lineWidth)
                    .frame(width: geo.size.width - (2 * config.lineWidth), height: geo.size.height - (2 * config.lineWidth))
                ActivityRingView(progress: $innerRingValue, mainColor: config.innerRingColor, lineWidth: config.lineWidth)
                    .frame(width: geo.size.width - (4 * config.lineWidth), height: geo.size.height - (4 * config.lineWidth))
            }
        }
    }
}
