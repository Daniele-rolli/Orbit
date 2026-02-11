//
//  OnboardingView.swift
//  Orbit
//
//

import SwiftUI
import Lottie

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var healthKitManager = HealthKitManager()
    @State private var ringSessionManager = RingSessionManager()
    @State private var currentPage = 0
    @State private var isRequestingAuth = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    ActivityPage().tag(1)
                    HeartRatePage().tag(2)
                    SleepPage().tag(3)
                    RingPairingPage(ringSessionManager: ringSessionManager).tag(4)
                    HealthKitAuthPage(isRequestingAuth: $isRequestingAuth).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                VStack(spacing: 20) {
                    PageIndicator(currentPage: currentPage, totalPages: 6)
                    
                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .environment(ringSessionManager)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 13) {
            if currentPage == 4 {
                // Ring Pairing Page
                if ringSessionManager.pickerDismissed && ringSessionManager.currentRing != nil {
                    // Ring is paired
                    if #available(iOS 26.0, *) {
                        Button(action: {
                            HapticManager.shared.light()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .semibold))
                                .cornerRadius(13)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    } else {
                        Button(action: {
                            HapticManager.shared.light()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .semibold))
                                .cornerRadius(13)
                        }
                    }
                } else {
                    // Waiting for ring pairing
                    if #available(iOS 26.0, *) {
                        Button(action: {
                            HapticManager.shared.light()
                            ringSessionManager.presentPicker()
                        }) {
                            Text("Pair Ring")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .semibold))
                                .cornerRadius(13)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    } else {
                        Button(action: {
                            HapticManager.shared.light()
                            ringSessionManager.presentPicker()
                        }) {
                            Text("Pair Ring")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .semibold))
                                .cornerRadius(13)
                        }
                    }
                    
                    Button(action: {
                        HapticManager.shared.light()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    }) {
                        Text("Set Up Later")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 17))
                    }
                }
                
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 17))
                }
            } else if currentPage == 5 {
                // HealthKit Auth Page
                if #available(iOS 26.0, *) {
                    Button(action: authorizeHealthKit) {
                        HStack(spacing: 8) {
                            if isRequestingAuth {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isRequestingAuth ? "Connecting..." : "Continue")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .semibold))
                        .cornerRadius(13)
                    }
                    .disabled(isRequestingAuth)
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                } else {
                    Button(action: authorizeHealthKit) {
                        HStack(spacing: 8) {
                            if isRequestingAuth {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isRequestingAuth ? "Connecting..." : "Continue")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .semibold))
                        .cornerRadius(13)
                    }
                    .disabled(isRequestingAuth)
                }
                
                Button(action: completeOnboarding) {
                    Text("Set Up Later")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 17))
                }
                
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 17))
                }
            } else {
                if #available(iOS 26.0, *) {
                    Button(action: {
                        HapticManager.shared.light()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .semibold))
                            .cornerRadius(13)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                } else {
                    Button(action: {
                        HapticManager.shared.light()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .semibold))
                            .cornerRadius(13)
                    }
                }
                
                if currentPage > 0 {
                    Button(action: {
                        HapticManager.shared.light()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    }) {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 17))
                    }
                }
            }
        }
    }
    
    private func authorizeHealthKit() {
        isRequestingAuth = true
        HapticManager.shared.light()
        
        Task {
            try? await healthKitManager.requestAuthorization()
            await MainActor.run {
                isRequestingAuth = false
                HapticManager.shared.success()
                completeOnboarding()
            }
        }
    }
    
    private func completeOnboarding() {
        HapticManager.shared.success()
        withAnimation(.easeInOut(duration: 0.3)) {
            hasSeenOnboarding = true
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "heart.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.blue)
                .padding(.bottom, 48)
            
            Text("Welcome to Orbit")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            Text("Your health data.\nCompletely private.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
        }
    }
}

// MARK: - Activity Page
struct ActivityPage: View {
    @State private var appear = false
    @State private var stepCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "figure.walk")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.bottom, 16)
            
            Text("\(stepCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .padding(.bottom, 32)
            
            Text("Activity")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            Text("Track your movement\nwithout sharing your location.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                if stepCount < 8247 {
                    stepCount += 157
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Heart Rate Page
struct HeartRatePage: View {
    @State private var appear = false
    @State private var heartRate = 0
    @State private var beat = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "heart.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.red)
                .scaleEffect(beat ? 1.05 : 1.0)
                .padding(.bottom, 16)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(heartRate)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                Text("BPM")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.red.opacity(0.7))
            }
            .padding(.bottom, 32)
            
            Text("Heart Rate")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            Text("Continuous monitoring.\nYour data never leaves your device.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
            
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                beat = true
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { timer in
                if heartRate < 72 {
                    heartRate += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Sleep Page
struct SleepPage: View {
    @State private var appear = false
    @State private var sleepHours: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.indigo)
                .padding(.bottom, 16)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", sleepHours))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)
                Text("hrs")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.indigo.opacity(0.7))
            }
            .padding(.bottom, 32)
            
            Text("Sleep")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            Text("Understand your rest patterns.\nAll analysis happens locally.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                sleepHours = 8.3
            }
        }
    }
}

// MARK: - Ring Pairing Page
struct RingPairingPage: View {
    @Bindable var ringSessionManager: RingSessionManager
    @State private var appear = false
    @State private var batteryInfo: BatteryInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if ringSessionManager.pickerDismissed, let currentRing = ringSessionManager.currentRing {
                // Ring is paired - show success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.bottom, 48)
                
                Text("Ring Connected")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)
                
                Text(currentRing.displayName)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
                
                // Show ring details card
                VStack(spacing: 16) {
                    HStack {
                        Image("colmi")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(currentRing.displayName)
                                .font(.headline.weight(.semibold))
                            
                            if let batteryInfo = batteryInfo {
                                HStack(spacing: 5) {
                                    BatteryView(isCharging: batteryInfo.charging, batteryLevel: batteryInfo.batteryLevel)
                                    Text(batteryInfo.batteryLevel, format: .percent)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Loading battery...")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .onAppear {
                    ringSessionManager.requestBatteryInfo { info in
                        DispatchQueue.main.async {
                            batteryInfo = info
                        }
                    }
                }
            } else {
                // Waiting for pairing
                Image(systemName: "circle.dotted")
                    .font(.system(size: 80, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 48)
                
                Text("Pair Your Ring")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)
                
                Text("Connect your smart ring\nto start tracking your health.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.bottom, 44)
                
                VStack(alignment: .leading, spacing: 24) {
                    PairingRow(
                          icon: "lock.shield",
                          title: "Private Data Access",
                          description: "View your ring data locally and securely"
                      )
                      
                      PairingRow(
                          icon: "iphone",
                          title: "Direct Connection",
                          description: "Connect to your ring using Bluetooth"
                      )
                      
                      PairingRow(
                          icon: "chart.line.uptrend.xyaxis",
                          title: "Clear Insights",
                          description: "Access your health data in a simple, readable format"
                      )
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
        }
    }
}

struct PairingRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - HealthKit
struct HealthKitAuthPage: View {
    @Binding var isRequestingAuth: Bool
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.blue)
                .padding(.bottom, 48)
            
            Text("Connect to Health")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            Text("Sync your ring with Apple Health.\nEverything stays on your device.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 44)
            
            VStack(alignment: .leading, spacing: 24) {
                PrivacyRow(
                    icon: "iphone.gen3",
                    title: "On Device Encryption",
                    description: "All data encrypted on your device"
                )
                
                PrivacyRow(
                    icon: "icloud.slash.fill",
                    title: "Zero Cloud Storage",
                    description: "Nothing uploaded, nothing tracked"
                )
                
                PrivacyRow(
                    icon: "hand.raised.fill",
                    title: "You're in Control",
                    description: "Change permissions anytime"
                )
            }
            .padding(.horizontal, 4)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appear = true
            }
        }
    }
}

struct PrivacyRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Page Indicator
struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.primary : Color.primary.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
    }
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
