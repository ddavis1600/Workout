import SwiftUI
import WatchConnectivity
import HealthKit

struct WatchContentView: View {
    @EnvironmentObject var service: WatchHeartRateService
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @ObservedObject private var workoutSession = WatchWorkoutSession.shared

    /// Workout type the user picks before tapping Start. Sent along with
    /// the "startWorkout" message so the iPhone logger opens with the
    /// right type + distance field pre-wired.
    @State private var selectedType: String = "strength"
    @State private var showingTypePicker = false

    /// Keep in sync with the iPhone-side list in LogWorkoutView.workoutTypeOptions.
    private static let workoutTypes: [(id: String, label: String)] = [
        ("strength",  "Strength"),
        ("running",   "Running"),
        ("cycling",   "Cycling"),
        ("walking",   "Walking"),
        ("hiit",      "HIIT"),
        ("yoga",      "Yoga"),
        ("swimming",  "Swimming"),
        ("other",     "Other"),
    ]

    private var currentTypeLabel: String {
        Self.workoutTypes.first { $0.id == selectedType }?.label ?? "Strength"
    }

    private var isDistanceType: Bool {
        ["running", "cycling", "walking", "swimming"].contains(selectedType)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 6) {
                    // Type picker — tap to change before starting.
                    Button {
                        showingTypePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.caption2)
                            Text(currentTypeLabel)
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isMonitoring)
                    .opacity(service.isMonitoring ? 0.5 : 1.0)

                    // BPM display
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(service.currentBPM > 0 ? "\(service.currentBPM)" : "–")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(zoneColor)
                        Text("BPM")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)
                    }

                    // Zone label
                    if service.currentBPM > 0 {
                        Text(service.zoneName)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(zoneColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(zoneColor.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    // Live GPS stats while a distance workout is active
                    if workoutSession.isActive && WatchWorkoutSession.usesGPS(workoutSession.activityType) {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: workoutSession.hasFirstFix ? "location.fill" : "location.slash")
                                    .font(.caption2)
                                    .foregroundColor(workoutSession.hasFirstFix ? .green : .gray)
                                Text(distanceLabel)
                                    .font(.footnote.weight(.semibold).monospacedDigit())
                                    .foregroundColor(.white)
                            }
                            if workoutSession.currentElevationGain > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "mountain.2.fill")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(elevationLabel)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Start / Stop button
                    Button {
                        if service.isMonitoring {
                            stopAll()
                        } else {
                            startAll()
                        }
                    } label: {
                        Label(
                            service.isMonitoring ? "Stop" : "Start",
                            systemImage: service.isMonitoring ? "stop.fill" : "heart.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(service.isMonitoring ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Last HR update
                    if let updated = service.lastUpdated {
                        Text(updated, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    // Surface any session error (HK auth denied / session
                    // couldn't start). Without this the user just sees the
                    // watch app suspend with no indication of what went wrong.
                    if let msg = workoutSession.errorMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(8)
            }
        }
        // iPhone finished/cancelled the workout — stop monitoring on Watch too
        .onChange(of: sessionManager.pendingStop) { stop in
            if stop {
                stopAll()
                sessionManager.pendingStop = false
            }
        }
        .sheet(isPresented: $showingTypePicker) {
            WorkoutTypePickerView(
                selected: $selectedType,
                types: Self.workoutTypes
            )
        }
    }

    // MARK: - Start/Stop

    /// Start HR monitoring, send the start signal to the phone, and
    /// kick off GPS tracking for distance activities. The `startDate` is
    /// included in the message so the iPhone can set its own session
    /// startDate to the same absolute instant — otherwise the phone's
    /// timer is behind by the round-trip latency of the WatchConnectivity
    /// delivery (often hundreds of ms, sometimes seconds).
    private func startAll() {
        let startInstant = Date()
        service.startMonitoring()
        WatchSessionManager.shared.sendMessage([
            "action":    "startWorkout",
            "type":      selectedType,
            "startDate": startInstant.timeIntervalSince1970,
        ])
        workoutSession.start(activityType: hkType(for: selectedType))
    }

    /// Stop HR, stop GPS tracking (which sends the final data payload to
    /// the phone), and send the stop signal.
    private func stopAll() {
        service.stopMonitoring()
        workoutSession.stop()
        WatchSessionManager.shared.sendStopWorkout()
    }

    // MARK: - Display helpers

    private var distanceLabel: String {
        // Simple imperial/metric guess — the watch doesn't know the user's
        // preference. We default to metric (km) and let the phone convert
        // for the saved workout / display.
        let km = workoutSession.currentDistanceMeters / 1000.0
        return String(format: "%.2f km", km)
    }

    private var elevationLabel: String {
        "\(Int(workoutSession.currentElevationGain.rounded())) m"
    }

    private var zoneColor: Color {
        switch service.zoneColor {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }

    /// Map watch workout-type string to HKWorkoutActivityType. Kept in sync
    /// with HealthKitManager.hkActivityType on the iPhone side.
    private func hkType(for id: String) -> HKWorkoutActivityType {
        switch id {
        case "running":   return .running
        case "cycling":   return .cycling
        case "walking":   return .walking
        case "hiit":      return .highIntensityIntervalTraining
        case "yoga":      return .yoga
        case "swimming":  return .swimming
        case "other":     return .other
        default:          return .traditionalStrengthTraining
        }
    }
}

// MARK: - Type picker sheet

private struct WorkoutTypePickerView: View {
    @Binding var selected: String
    let types: [(id: String, label: String)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(types, id: \.id) { type in
                Button {
                    selected = type.id
                    dismiss()
                } label: {
                    HStack {
                        Text(type.label)
                            .foregroundColor(.white)
                        Spacer()
                        if selected == type.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.gray.opacity(0.15))
            }
        }
        .navigationTitle("Workout Type")
    }
}
