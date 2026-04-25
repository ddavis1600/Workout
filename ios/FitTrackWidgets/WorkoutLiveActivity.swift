import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// `ActivityConfiguration` registration for the active-workout
/// Live Activity (audit ref F3).
///
/// Three layouts are required:
///   1. **Lock screen / Notification banner** — `ActivityConfiguration`'s
///      first closure. Shows workout name, big elapsed timer,
///      calories, optional progress bar against a target duration.
///   2. **Dynamic Island expanded** — large open layout with
///      leading / trailing / bottom regions and a Stop button
///      backed by an App Intent.
///   3. **Dynamic Island compact** — collapsed pair (left + right)
///      shown when the activity isn't expanded.
///   4. **Dynamic Island minimal** — single glyph when other
///      activities are competing for the island.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock-screen / banner
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — leading / trailing / bottom regions
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: context.attributes.workoutSymbol)
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture,
                     pauseTime: nil,
                     countsDown: false,
                     showsHours: true)
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: context.attributes.workoutSymbol)
                    .foregroundStyle(.green)
            }
            .keylineTint(.green)
        }
    }

    // MARK: - Dynamic Island expanded regions

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: context.attributes.workoutSymbol)
                    .foregroundStyle(.green)
                Text(context.attributes.workoutName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Text(timerInterval: context.attributes.startDate...Date.distantFuture,
                 pauseTime: nil,
                 countsDown: false,
                 showsHours: true)
                .monospacedDigit()
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(context.state.caloriesBurned)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            if let bpm = context.state.heartRateBPM {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(bpm)")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        // Stop button — the App Intent ends the workout from
        // outside the app process, satisfying the F3 spec
        // "Stop button on the expanded Dynamic Island uses an App
        // Intent so it can end the workout from outside the app".
        HStack {
            Spacer()
            Button(intent: StopWorkoutIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Lock-screen layout

/// Full-bleed lock-screen banner. Lays out:
///   - Title row: workout symbol + name + "Active" badge.
///   - Big timer driven by `Text(timerInterval:)` so it ticks
///     without push updates.
///   - Calorie + heart-rate row (heart hidden when nil).
///   - Optional progress bar against `targetDurationMinutes`.
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var endDate: Date {
        if let target = context.attributes.targetDurationMinutes {
            return context.attributes.startDate.addingTimeInterval(TimeInterval(target * 60))
        }
        return Date.distantFuture
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: context.attributes.workoutSymbol)
                    .font(.title3)
                    .foregroundStyle(.green)
                Text(context.attributes.workoutName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("ACTIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(.green)
            }

            Text(timerInterval: context.attributes.startDate...Date.distantFuture,
                 pauseTime: nil,
                 countsDown: false,
                 showsHours: true)
                .monospacedDigit()
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 18) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(context.state.caloriesBurned) kcal")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                if let bpm = context.state.heartRateBPM {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(bpm) BPM")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
            }

            if let target = context.attributes.targetDurationMinutes, target > 0 {
                ProgressView(timerInterval: context.attributes.startDate...endDate,
                             countsDown: false)
                    .tint(.green)
                    .labelsHidden()
            }
        }
        .padding()
    }
}
