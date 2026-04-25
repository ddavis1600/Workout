import WidgetKit
import SwiftUI

/// "Today's Stats" widget — small + medium families.
///
/// Small: vertical stack of calories consumed (with target) + steps.
/// Medium: horizontal grid of consumed / burned / steps + a slim
/// progress bar against the calorie target.
///
/// Why these three numbers: the spec lists "calories burned, calories
/// consumed, steps, primary metric to glance at". Calorie target is a
/// secondary affordance that turns the consumed number into actionable
/// info ("1450/2000") rather than a raw count.
struct TodayStatsWidget: Widget {
    let kind: String = "TodayStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            TodayStatsWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Stats")
        .description("Calories and steps for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayStatsWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        default:            smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.caloriesConsumed)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("of \(snapshot.calorieTarget) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressFraction)
                .tint(.orange)

            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.caption)
                Text("\(snapshot.steps) steps")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.lastUpdated, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                statColumn(
                    icon: "fork.knife",
                    value: "\(snapshot.caloriesConsumed)",
                    label: "Eaten",
                    color: .orange
                )
                statColumn(
                    icon: "flame",
                    value: "\(snapshot.caloriesBurned)",
                    label: "Burned",
                    color: .red
                )
                statColumn(
                    icon: "figure.walk",
                    value: "\(snapshot.steps)",
                    label: "Steps",
                    color: .blue
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: progressFraction)
                    .tint(.orange)
                Text("\(snapshot.caloriesConsumed) / \(snapshot.calorieTarget) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statColumn(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progressFraction: Double {
        guard snapshot.calorieTarget > 0 else { return 0 }
        return min(1, Double(snapshot.caloriesConsumed) / Double(snapshot.calorieTarget))
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TodayStatsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
        caloriesConsumed: 1450, caloriesBurned: 420, steps: 7800,
        calorieTarget: 2000
    ))
}

#Preview(as: .systemMedium) {
    TodayStatsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
        caloriesConsumed: 1450, caloriesBurned: 420, steps: 7800,
        calorieTarget: 2000
    ))
}
