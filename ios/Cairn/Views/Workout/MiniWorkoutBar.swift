import SwiftUI

/// Compact persistent bar shown above the tab bar when a workout is active
/// but minimized. Tap to expand back to LogWorkoutView.
///
/// Rendered by ContentView between `tabContent(...)` and the tab bar
/// `Divider` — inline in the VStack, so tabs stay tappable.
struct MiniWorkoutBar: View {
    @ObservedObject private var session = WorkoutSessionManager.shared
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @State private var tick = Date()   // forces per-second re-render of elapsed

    var body: some View {
        Button {
            session.expand()
        } label: {
            HStack(spacing: 12) {
                // Recording indicator
                Circle()
                    .fill(session.isPaused ? Color.slateText : Color.red)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.workoutName.isEmpty ? "Workout" : session.workoutName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(elapsedLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.slateText)
                        if let bpm = watchManager.liveHeartRate {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.red)
                                Text("\(Int(bpm))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Color.slateText)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.emerald)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.slateCard)
            .overlay(
                Rectangle()
                    .fill(Color.slateBorder)
                    .frame(height: 0.5),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            tick = now
        }
    }

    private var elapsedLabel: String {
        _ = tick // referenced to force redraw
        let s = session.elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
