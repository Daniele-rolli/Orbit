//
//  Orbit.swift
//  Orbit
//
//

import SwiftUI

@main
struct Orbit: App {
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView(hasSeenOnboarding: $appState.hasSeenOnboarding)
            }
        }
    }
}
