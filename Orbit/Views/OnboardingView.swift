//
//  OnboardingView.swift
//  Orbit
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var ringSessionManager = RingSessionManager()
    @State private var currentPage = 0

    // User profile state (persisted)
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userAge") private var userAge: Int = 30
    @AppStorage("userHeightCm") private var userHeightCm: Int = 170
    @AppStorage("userWeightKg") private var userWeightKg: Int = 70
    @AppStorage("userMeasurementSystem") private var userMeasurementSystem: Int = 0
    @AppStorage("userTimeFormat") private var userTimeFormat: Int = 0

    private let totalPages = 6

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    ActivityPage().tag(1)
                    HeartRatePage().tag(2)
                    SleepPage().tag(3)
                    UserProfilePage(
                        gender: $userGender,
                        age: $userAge,
                        heightCm: $userHeightCm,
                        weightKg: $userWeightKg,
                        measurementSystem: $userMeasurementSystem,
                        timeFormat: $userTimeFormat
                    ).tag(4)
                    RingPairingPage(ringSessionManager: ringSessionManager).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 20) {
                    PageIndicator(currentPage: currentPage, totalPages: totalPages)
                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .environment(ringSessionManager)
    }

    private var actionButtons: some View {
        VStack(spacing: 13) {
            if currentPage == 5 {
                // Ring pairing page
                if ringSessionManager.pickerDismissed && ringSessionManager.currentRing != nil {
                    primaryButton("Get Started") {
                        applyUserProfileToRing()
                        completeOnboarding()
                    }
                } else {
                    primaryButton("Pair Ring") {
                        ringSessionManager.presentPicker()
                    }
                    secondaryButton("Set Up Later") { completeOnboarding() }
                }
                backButton()
            } else {
                primaryButton("Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                }
                if currentPage > 0 { backButton() }
            }
        }
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button(action: { HapticManager.shared.light(); action() }) {
                Text(title)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .cornerRadius(13)
            }
            .buttonStyle(.glassProminent).tint(.blue)
        } else {
            Button(action: { HapticManager.shared.light(); action() }) {
                Text(title)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .cornerRadius(13)
            }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.shared.light(); action() }) {
            Text(title)
                .frame(maxWidth: .infinity).frame(height: 50)
                .foregroundColor(.accentColor)
                .font(.system(size: 17))
        }
    }

    private func backButton() -> some View {
        Button(action: {
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.3)) { currentPage -= 1 }
        }) {
            Text("Back")
                .frame(maxWidth: .infinity).frame(height: 50)
                .foregroundColor(.accentColor)
                .font(.system(size: 17))
        }
    }

    private func applyUserProfileToRing() {
        let prefs = UserPreferences(
            gender: UserPreferences.Gender(rawValue: UInt8(userGender)) ?? .male,
            age: userAge,
            heightCm: userHeightCm,
            weightKg: userWeightKg,
            measurementSystem: UserPreferences.MeasurementSystem(rawValue: UInt8(userMeasurementSystem)) ?? .metric,
            timeFormat: UserPreferences.TimeFormat(rawValue: UInt8(userTimeFormat)) ?? .twentyFourHour,
            systolicBP: 120,
            diastolicBP: 80,
            hrWarningThreshold: 180
        )
        ringSessionManager.setUserPreferences(prefs)
        // Enable all continuous monitoring by default
        ringSessionManager.enableAllMonitoring()
    }

    private func completeOnboarding() {
        HapticManager.shared.success()
        withAnimation(.easeInOut(duration: 0.3)) { hasSeenOnboarding = true }
    }
}

// MARK: - User Profile Page

struct UserProfilePage: View {
    @Binding var gender: Int
    @Binding var age: Int
    @Binding var heightCm: Int
    @Binding var weightKg: Int
    @Binding var measurementSystem: Int
    @Binding var timeFormat: Int

    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 12)

                Text("Your Profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                Text("Helps your ring calculate accurate calories, steps and sleep.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 32)

                VStack(spacing: 0) {
                    profileRow("Biological Sex") {
                        Picker("", selection: $gender) {
                            Text("Male").tag(0)
                            Text("Female").tag(1)
                            Text("Other").tag(2)
                        }
                        .pickerStyle(.menu)
                    }
                    divider()

                    profileRow("Age") {
                        HStack {
                            Text("\(age) yrs").foregroundStyle(.secondary)
                            Stepper("", value: $age, in: 10...99).labelsHidden()
                        }
                    }
                    divider()

                    profileRow(measurementSystem == 0 ? "Height" : "Height") {
                        HStack {
                            Text(heightDisplay).foregroundStyle(.secondary)
                            Stepper("", value: $heightCm, in: 100...220).labelsHidden()
                        }
                    }
                    divider()

                    profileRow(measurementSystem == 0 ? "Weight" : "Weight") {
                        HStack {
                            Text(weightDisplay).foregroundStyle(.secondary)
                            Stepper("", value: $weightKg, in: 30...200).labelsHidden()
                        }
                    }
                    divider()

                    profileRow("Units") {
                        Picker("", selection: $measurementSystem) {
                            Text("Metric").tag(0)
                            Text("Imperial").tag(1)
                        }
                        .pickerStyle(.menu)
                    }
                    divider()

                    profileRow("Time Format") {
                        Picker("", selection: $timeFormat) {
                            Text("24-hour").tag(0)
                            Text("12-hour").tag(1)
                        }
                        .pickerStyle(.menu)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
        }
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appear = true } }
    }

    private var heightDisplay: String {
        if measurementSystem == 0 { return "\(heightCm) cm" }
        let totalInches = Int(Double(heightCm) / 2.54)
        return "\(totalInches / 12)'\(totalInches % 12)\""
    }

    private var weightDisplay: String {
        if measurementSystem == 0 { return "\(weightKg) kg" }
        return "\(Int(Double(weightKg) * 2.205)) lbs"
    }

    private func profileRow<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(label).font(.system(size: 17))
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func divider() -> some View {
        Divider().padding(.leading, 16)
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    @State private var appear = false
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "heart.fill").font(.system(size: 80, weight: .semibold)).foregroundStyle(.blue).padding(.bottom, 48)
            Text("Welcome to Orbit").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
            Text("Your health data.\nCompletely private.").font(.system(size: 17)).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(2)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appear = true } }
    }
}

// MARK: - Activity Page

struct ActivityPage: View {
    @State private var appear = false
    @State private var stepCount = 0
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "figure.walk").font(.system(size: 80, weight: .semibold)).foregroundStyle(.green).padding(.bottom, 16)
            Text("\(stepCount)").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundColor(.green).padding(.bottom, 32)
            Text("Activity").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
            Text("Track your movement\nwithout sharing your location.").font(.system(size: 17)).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(2)
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
                if stepCount < 8247 { stepCount += 157 } else { t.invalidate() }
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
            Image(systemName: "heart.fill").font(.system(size: 80, weight: .semibold)).foregroundStyle(.red).scaleEffect(beat ? 1.05 : 1.0).padding(.bottom, 16)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(heartRate)").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundColor(.red)
                Text("BPM").font(.system(size: 17, weight: .semibold)).foregroundColor(.red.opacity(0.7))
            }.padding(.bottom, 32)
            Text("Heart Rate").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
            Text("Continuous monitoring.\nYour data never leaves your device.").font(.system(size: 17)).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(2)
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { beat = true }
            Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { t in
                if heartRate < 72 { heartRate += 1 } else { t.invalidate() }
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
            Image(systemName: "moon.stars.fill").font(.system(size: 80, weight: .semibold)).foregroundStyle(.indigo).padding(.bottom, 16)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", sleepHours)).font(.system(size: 48, weight: .bold, design: .rounded)).foregroundColor(.indigo)
                Text("hrs").font(.system(size: 17, weight: .semibold)).foregroundColor(.indigo.opacity(0.7))
            }.padding(.bottom, 32)
            Text("Sleep").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
            Text("Understand your rest patterns.\nAll analysis happens locally.").font(.system(size: 17)).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(2)
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { sleepHours = 8.3 }
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
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80, weight: .semibold)).foregroundStyle(.green).padding(.bottom, 48)
                Text("Ring Connected").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
                Text(currentRing.displayName).font(.system(size: 17)).foregroundColor(.secondary).padding(.bottom, 4)
                Text("All monitoring features will be enabled.").font(.system(size: 15)).foregroundColor(.secondary).padding(.bottom, 32)

                HStack {
                    Image("colmi").resizable().aspectRatio(contentMode: .fit).frame(height: 60)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(currentRing.displayName).font(.headline.weight(.semibold))
                        if let b = batteryInfo {
                            HStack(spacing: 5) {
                                BatteryView(isCharging: b.charging, batteryLevel: b.batteryLevel)
                                Text(b.batteryLevel, format: .percent).font(.footnote).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Loading battery...").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .onAppear {
                    ringSessionManager.requestBatteryInfo { info in
                        DispatchQueue.main.async { batteryInfo = info }
                    }
                }
            } else {
                Image(systemName: "circle.dotted").font(.system(size: 80, weight: .semibold)).foregroundStyle(.blue).padding(.bottom, 48)
                Text("Pair Your Ring").font(.system(size: 34, weight: .bold)).foregroundColor(.primary).padding(.bottom, 8)
                Text("Connect your smart ring\nto start tracking your health.").font(.system(size: 17)).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(2).padding(.bottom, 44)

                VStack(alignment: .leading, spacing: 24) {
                    PairingRow(icon: "lock.shield", title: "Private Data Access", description: "View your ring data locally and securely")
                    PairingRow(icon: "iphone", title: "Direct Connection", description: "Connect to your ring using Bluetooth")
                    PairingRow(icon: "chart.line.uptrend.xyaxis", title: "Clear Insights", description: "Access your health data in a simple, readable format")
                }
                .padding(.horizontal, 4)
            }
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appear = true } }
    }
}

struct PairingRow: View {
    let icon: String; let title: String; let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.blue).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                Text(description).font(.system(size: 15)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Page Indicator

struct PageIndicator: View {
    let currentPage: Int; let totalPages: Int
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0 ..< totalPages, id: \.self) { i in
                Circle().fill(currentPage == i ? Color.primary : Color.primary.opacity(0.2)).frame(width: 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
    }
}

// MARK: - Haptic Manager

class HapticManager {
    static let shared = HapticManager()
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

#Preview { OnboardingView(hasSeenOnboarding: .constant(false)) }
