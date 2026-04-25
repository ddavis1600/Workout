import Foundation
import ActivityKit
import os.log

/// Thin wrapper around `ActivityKit` for managing the workout Live
/// Activity (audit ref F3). One activity at a time — the manager
/// holds the live `Activity<WorkoutActivityAttributes>` reference
/// so the various callers (start, periodic update, stop) don't have
/// to re-fetch it.
///
/// Why a singleton: the active-workout flow lives across multiple
/// view-model boundaries (LogWorkoutView, the App Intent stop
/// path, the watch-stop signal) and they all need to point at the
/// same activity record. Static singleton matches the existing
/// `HealthKitManager.shared` / `WatchConnectivityManager.shared`
/// pattern in the project.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private static let log = Logger(subsystem: "com.danieldavis16.fittrack", category: "live-activity")

    /// Currently-running activity, if any. Nil when no workout is
    /// active or the platform refused the request (entitlement
    /// missing, Live Activities disabled in Settings, etc.).
    private(set) var current: Activity<WorkoutActivityAttributes>?

    // MARK: - Start

    /// Start a new Live Activity for an active workout. No-op if
    /// the platform reports activities are disabled, or if one is
    /// already running (the caller should `endActivity()` first if
    /// they want to swap).
    func startActivity(
        workoutName: String,
        workoutType: String?,
        startDate: Date,
        targetDurationMinutes: Int? = nil,
        initialCalories: Int = 0,
        initialHeartRate: Int? = nil
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.log.info("Live Activities disabled in iOS Settings — not starting")
            return
        }
        guard current == nil else {
            Self.log.warning("startActivity called while one is already running — ignoring")
            return
        }

        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName.isEmpty ? "Workout" : workoutName,
            workoutSymbol: WorkoutActivityAttributes.symbol(for: workoutType),
            startDate: startDate,
            targetDurationMinutes: targetDurationMinutes
        )
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            caloriesBurned: initialCalories,
            heartRateBPM: initialHeartRate
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil  // local-only for v1; push tokens land in P9+
            )
            current = activity
            Self.log.info("Live Activity started: \(activity.id, privacy: .public)")
        } catch {
            Self.log.error("Live Activity request failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Update

    /// Push a fresh state to the Live Activity. Call every ~5s
    /// from the workout view's timer tick — more frequent updates
    /// burn the activity's push budget without visible benefit
    /// (timer text comes from `Text(.timerInterval)` and ticks on
    /// its own).
    func updateActivity(elapsedSeconds: Int, caloriesBurned: Int, heartRateBPM: Int?) {
        guard let activity = current else { return }
        let newState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            caloriesBurned: caloriesBurned,
            heartRateBPM: heartRateBPM
        )
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }

    // MARK: - End

    /// End the current activity. `dismissAfter` lets the lock-screen
    /// banner linger briefly so the user sees a final summary; nil
    /// dismisses immediately.
    func endActivity(finalCalories: Int? = nil, dismissAfter delay: TimeInterval = 2) {
        guard let activity = current else { return }
        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedSeconds: activity.content.state.elapsedSeconds,
            caloriesBurned: finalCalories ?? activity.content.state.caloriesBurned,
            heartRateBPM: nil  // session is over — clear the live HR slot
        )
        let dismissalPolicy: ActivityUIDismissalPolicy = delay > 0
            ? .after(.now + delay)
            : .immediate
        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: dismissalPolicy
            )
        }
        current = nil
        Self.log.info("Live Activity ended")
    }

    /// Force-cancel any ongoing activity without a final-state
    /// hand-off. Used by the App Intent stop path when we don't
    /// have a fresh state to push (the intent fires from outside
    /// the app process).
    func endAllImmediately() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        current = nil
    }
}
