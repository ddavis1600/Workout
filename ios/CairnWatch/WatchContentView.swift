import SwiftUI
import WatchConnectivity
import HealthKit

/// Main watch view. Layout mirrors the phone's WorkoutHeartRateCard:
/// elapsed timer at top, big BPM + zone, GPS stats for outdoor workouts,
/// big Start/Stop button. Everything is driven off singletons
/// (WatchWorkoutSession / WatchHeartRateService) so values stay consistent
/// whether the view is foreground or not.
struct WatchContentView: View {
    @EnvironmentObject var service: WatchHeartRateService
    @ObservedObject private var sessionManager  = WatchSessionManager.shared
    @ObservedObject private var workoutSession  = WatchWorkoutSession.shared

    /// Workout type the user picks before tapping Start. Sent along with
    /// the "startWorkout" message so the iPhone logger opens with the
    /// right type + distance field pre-wired.
    @State private var selectedType: String = "strength"
    @State private var showingTypePicker = false
    /// Drives per-second re-renders of the elapsed timer. The timer value
    /// itself is always computed from WatchWorkoutSession.pendingStartAt,
    /// so this tick is only a "please redraw" nudge — no drift possible.
    @State private var tick = Date()

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

    private var isActive: Bool { service.isMonitoring || workoutSession.isActive }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    typePill
                    if isActive {
                        elapsedTimer
                    }
                    bpmSection
                    if workoutSession.isActive && WatchWorkoutSession.usesGPS(workoutSession.activityType) {
                        gpsStats
                    }
                    startStopButton
                    if let msg = workoutSession.errorMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
        .onChange(of: sessionManager.pendingStop) { stop in
            // Belt-and-suspenders: WatchSessionManager now stops the session
            // directly, but if this view happens to be mounted it'll also
            // catch the flag and force a UI refresh.
            if stop {
                stopAll()
                sessionManager.pendingStop = false
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            tick = now
        }
        .sheet(isPresented: $showingTypePicker) {
            WorkoutTypePickerView(selected: $selectedType, types: Self.workoutTypes)
        }
    }

    // MARK: - Sections

    private var typePill: some View {
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
        .disabled(isActive)
        .opacity(isActive ? 0.5 : 1.0)
    }

    /// Giant elapsed timer — the same value the phone shows. Always
    /// recomputed from `pendingStartAt` on each redraw so a stale `tick`
    /// never lies about the time.
    private var elapsedTimer: some View {
        _ = tick
        let s = workoutSession.elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        let label = h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
        return Text(label)
            .font(.system(size: 30, weight: .semibold, design: .monospaced))
            .foregroundColor(.green)
            .padding(.vertical, 2)
    }

    private var bpmSection: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(service.currentBPM > 0 ? "\(service.currentBPM)" : "–")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(zoneColor)
                Text("BPM")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 3)
            }

            if service.currentBPM > 0 {
                Text(service.zoneName)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(zoneColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(zoneColor.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }

    /// Distance / pace / elevation for outdoor workouts. Pace only shows
    /// once we have >= ~100 m of distance — before that it's noisy.
    private var gpsStats: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: workoutSession.hasFirstFix ? "location.fill" : "location.slash")
                    .font(.caption2)
                    .foregroundColor(workoutSession.hasFirstFix ? .green : .gray)
                Text(distanceLabel)
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                if let pace = paceLabel {
                    Text("•").foregroundColor(.gray)
                    Text(pace)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray)
                }
            }
            if workoutSession.currentElevationGain > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "mountain.2.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(elevationLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var startStopButton: some View {
        Button {
            if isActive { stopAll() } else { startAll() }
        } label: {
            Label(
                isActive ? "Stop" : "Start",
                systemImage: isActive ? "stop.fill" : "play.fill"
            )
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Start/Stop

    private func startAll() {
        let startInstant = Date()
        service.startMonitoring()
        WatchSessionManager.shared.sendMessage([
            "action":    "startWorkout",
            "type":      selectedType,
            "startDate": startInstant.timeIntervalSince1970,
        ])
        workoutSession.start(activityType: hkType(for: selectedType), startAt: startInstant)
    }

    private func stopAll() {
        service.stopMonitoring()
        workoutSession.stop()
        WatchSessionManager.shared.sendStopWorkout()
    }

    // MARK: - Display helpers

    private var distanceLabel: String {
        // Metric on the watch — we don't know the user's preference here
        // and the phone re-formats when saving anyway.
        let km = workoutSession.currentDistanceMeters / 1000.0
        return String(format: "%.2f km", km)
    }

    /// Average pace in min/km, only shown after ≥ 100 m so early noise
    /// doesn't render nonsense like "1:08 /km" during the GPS warm-up.
    private var paceLabel: String? {
        _ = tick
        guard workoutSession.currentDistanceMeters >= 100 else { return nil }
        let elapsed = Double(workoutSession.elapsedSeconds)
        guard elapsed > 0 else { return nil }
        let km = workoutSession.currentDistanceMeters / 1000.0
        guard km > 0 else { return nil }
        let secPerKm = elapsed / km
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
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

    /// Map watch workout-type string to HKWorkoutActivityType.
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
