import WidgetKit
import SwiftUI

/// "Today's Workout" widget — medium family only.
///
/// If a workout exists for today (any time): name + duration + a
/// "Logged" badge. If not: an empty-state CTA encouraging the user to
/// open the app and log one. Empty state is the primary case for most
/// users most days, so it gets visual weight rather than a tiny gray
/// label.
struct TodayWorkoutWidget: Widget {
    let kind: String = "TodayWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            TodayWorkoutWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Workout")
        .description("What you logged today, or a CTA if not.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayWorkoutWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let name = snapshot.todayWorkoutName {
            loggedWorkout(name: name)
        } else {
            emptyCTA
        }
    }

    // MARK: - Logged

    private func loggedWorkout(name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.green)
                Text("Today's Workout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Logged")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.18), in: Capsule())
                    .foregroundStyle(.green)
            }

            Text(name)
                .font(.title2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 14) {
                if let minutes = snapshot.todayWorkoutDurationMinutes, minutes > 0 {
                    Label(formatDuration(minutes: minutes), systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(minutes) min"
    }

    // MARK: - Empty CTA

    private var emptyCTA: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "dumbbell")
                    .foregroundStyle(.secondary)
                Text("Today's Workout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("No workout logged yet")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Tap to start one in FitTrack")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    TodayWorkoutWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
        todayWorkoutName: "Push Day", todayWorkoutDurationMinutes: 52
    ))
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot())
}
