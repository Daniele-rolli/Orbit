//
//  AppState.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/29/26.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        }
    }

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }
}
