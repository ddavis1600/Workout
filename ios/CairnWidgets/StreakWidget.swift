import WidgetKit
import SwiftUI

/// "Streak" widget — small family only.
///
/// Shows the current longest-streak habit's day count with a flame
/// visual. The main app picks the habit with the highest current streak
/// when refreshing the snapshot, so this widget always represents the
/// user's "best active" streak rather than picking arbitrarily.
///
/// Empty state: if no habits exist or every streak is 0, the widget
/// shows a neutral "Start a habit" message instead of "0 days".
struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            StreakWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Your longest active habit streak.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.currentStreak > 0 {
            activeStreak
        } else {
            emptyState
        }
    }

    private var activeStreak: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Streak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.currentStreak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text(snapshot.currentStreak == 1 ? "day" : "days")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !snapshot.streakHabitName.isEmpty {
                Text(snapshot.streakHabitName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame")
                    .foregroundStyle(.secondary)
                Text("Streak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("Start a habit")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Tap to open Cairn")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
        currentStreak: 7, streakHabitName: "Morning Stretch"
    ))
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(currentStreak: 0))
}
