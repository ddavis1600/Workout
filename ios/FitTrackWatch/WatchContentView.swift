import SwiftUI
import WatchConnectivity

struct WatchContentView: View {
    @EnvironmentObject var service: WatchHeartRateService
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    /// Workout type the user picks before tapping Start. Sent along with
    /// the "startWorkout" message so the iPhone logger opens with the
    /// right type + distance field pre-wired (r2 feedback item 1).
    @State private var selectedType: String = "strength"
    @State private var showingTypePicker = false

    /// Keep in sync with the iPhone-side list in LogWorkoutView.workoutTypeOptions.
    /// Duplicated here rather than shared because the Watch target can't link
    /// to LogWorkoutView.swift's containing iOS target.
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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 6) {
                // Type picker — tap to change before starting.
                // Disabled once monitoring starts to prevent mid-workout changes.
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
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(zoneColor)
                    Text("BPM")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }

                // Zone label
                if service.currentBPM > 0 {
                    Text(service.zoneName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(zoneColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(zoneColor.opacity(0.2))
                        .clipShape(Capsule())
                }

                // Start / Stop button
                Button {
                    if service.isMonitoring {
                        service.stopMonitoring()
                        WatchSessionManager.shared.sendStopWorkout()
                    } else {
                        service.startMonitoring()
                        // Send the selected type with the start message so the
                        // phone can open the logger with the right setup.
                        WatchSessionManager.shared.sendMessage([
                            "action": "startWorkout",
                            "type":   selectedType,
                        ])
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

                // Last updated
                if let updated = service.lastUpdated {
                    Text(updated, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        // iPhone finished/cancelled the workout — stop monitoring on Watch too
        .onChange(of: sessionManager.pendingStop) { stop in
            if stop {
                service.stopMonitoring()
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

    private var zoneColor: Color {
        switch service.zoneColor {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }
}

// MARK: - Type picker sheet

/// Full-screen list on the watch for selecting a workout type. Separate sheet
/// because the iPhone-style Menu picker is awkward on the small watch screen.
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
