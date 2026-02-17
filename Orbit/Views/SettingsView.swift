//
//  SettingsView.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/28/26.
//

import AccessorySetupKit
import HealthKit
import SwiftUI

struct SettingsView: View {
    @Environment(RingSessionManager.self) var ringSessionManager
    @State private var batteryInfo: BatteryInfo?

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    @State private var healthKitEnabled = false
    @State private var healthKitAuthorized = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Device Section

                Section("MY DEVICE") {
                    if ringSessionManager.pickerDismissed, let currentRing = ringSessionManager.currentRing {
                        makeRingView(ring: currentRing)
                            .onAppear {
                                ringSessionManager.requestBatteryInfo { info in
                                    DispatchQueue.main.async {
                                        batteryInfo = info
                                    }
                                }
                            }
                    } else {
                        Button {
                            ringSessionManager.presentPicker()
                        } label: {
                            Text("Add Ring")
                                .frame(maxWidth: .infinity)
                                .font(.headline.weight(.semibold))
                        }
                    }
                }

                // MARK: - HealthKit Section

                Section("HEALTH DATA") {
                    Toggle(isOn: $healthKitEnabled) {
                        Text("Sync with Health")
                    }
                    .onChange(of: healthKitEnabled) { newValue in
                        if newValue {
                            requestHealthKitAccess()
                        } else {
                            healthKitAuthorized = false
                        }
                    }

                    if healthKitEnabled {
                        if healthKitAuthorized {
                            Label("HealthKit Enabled", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Awaiting Authorization", systemImage: "hourglass")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("HealthKit not synced")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Delete Ring

                if ringSessionManager.peripheralConnected {
                    Section {
                        Button(action: {
                            ringSessionManager.removeRing()
                        }, label: {
                            Text("Delete Ring")
                                .frame(maxWidth: .infinity)
                                .tint(.red)
                        })
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Device")
        }
    }

    // MARK: - HealthKit Authorization

    private func requestHealthKitAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        let typesToShare: Set = [heartRateType, stepCountType, activeEnergyType]
        let typesToRead: Set = [heartRateType, stepCountType, activeEnergyType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                healthKitAuthorized = success
                if !success {
                    print("HealthKit authorization failed: \(String(describing: error))")
                    healthKitEnabled = false
                }
            }
        }
    }

    // MARK: - Ring View

    private func makeRingView(ring: ASAccessory) -> some View {
        HStack {
            Image("colmi")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text(ring.displayName)
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
    }
}

#Preview {
    SettingsView()
        .environment(RingSessionManager())
}
