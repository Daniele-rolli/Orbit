//
//  Orbit.swift
//  Orbit
//
//

import BackgroundTasks
import SwiftUI

@main
struct Orbit: App {
    @StateObject var appState = AppState()

    init() {
        // Register background refresh task for periodic data save
        RingSessionManager.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            if appState.hasSeenOnboarding {
                ContentView()
                    .onBackground {
                        RingSessionManager.scheduleBackgroundSync()
                    }
            } else {
                OnboardingView(hasSeenOnboarding: $appState.hasSeenOnboarding)
            }
        }
    }
}

// MARK: - View extension for background/foreground events

extension View {
    func onBackground(_ action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            action()
        }
    }
}
