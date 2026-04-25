import Foundation
import ActivityKit

/// Attribute set that backs the active-workout Live Activity (audit
/// ref F3). Defines what's static for the lifetime of the Activity
/// (workout name, type, start time, optional target duration) and
/// what changes over time on the lock screen / Dynamic Island
/// (`ContentState`).
///
/// This file lives in the **main app target** AND the **widget
/// extension target** so both sides agree on the wire format.
/// `Codable` + `Hashable` are inherited from `ActivityAttributes`,
/// which is what ActivityKit serialises across the app/extension
/// boundary.
///
/// Why these particular fields:
///   - `workoutName` + `workoutType` — static labels for the
///     compact / minimal Dynamic Island states. We don't push
///     these in `ContentState` because they don't change during a
///     session and the budget for state pushes is tight.
///   - `startDate` — anchors all timer math. With `startDate` in
///     attributes the lock-screen view uses
///     `Text(.timerInterval(start:end:))` for tick-accurate
///     rendering without us scheduling pushes every second.
///   - `targetDurationMinutes` — optional. When set, the lock
///     screen shows a thin progress bar; otherwise the elapsed
///     timer fills the slot.
///   - `ContentState.elapsedSeconds` — pushed every ~5 s so the
///     calorie / pace numbers stay fresh. Time itself is
///     derived from `startDate` so it ticks even without pushes.
///   - `ContentState.caloriesBurned` — running estimate. Right now
///     this is a duration × MET proxy in the main app; a future
///     change can swap it for HK active-energy.
///   - `ContentState.heartRateBPM` — last sampled bpm if the watch
///     or HK session is providing one. `nil` collapses to the
///     elapsed-only Dynamic Island compact layout.
struct WorkoutActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic content (pushed via Activity.update)

    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var caloriesBurned: Int
        /// Last sampled heart rate in BPM. `nil` = no live HR
        /// stream — the widget hides the heart icon in that case.
        var heartRateBPM: Int?
    }

    // MARK: - Static (set once at start)

    var workoutName: String

    /// SF Symbol name describing the workout. Maps from the user's
    /// chosen workout type ("Running" → "figure.run", "Cycling" →
    /// "figure.outdoor.cycle", strength → "dumbbell.fill"). Stored
    /// rather than computed so the widget extension doesn't need
    /// the resolution logic.
    var workoutSymbol: String

    var startDate: Date

    /// Optional target duration in minutes. When `nil`, the lock
    /// screen omits the progress bar.
    var targetDurationMinutes: Int?
}

// MARK: - Symbol resolution

extension WorkoutActivityAttributes {
    /// Resolve a workout name / type string to an SF Symbol. The
    /// main app calls this when starting the Activity so the value
    /// is locked in the static attributes.
    static func symbol(for workoutType: String?) -> String {
        guard let type = workoutType?.lowercased() else { return "dumbbell.fill" }
        switch type {
        case let s where s.contains("run"):       return "figure.run"
        case let s where s.contains("walk"):      return "figure.walk"
        case let s where s.contains("cycl"),
             let s where s.contains("bike"):      return "figure.outdoor.cycle"
        case let s where s.contains("swim"):      return "figure.pool.swim"
        case let s where s.contains("yoga"):      return "figure.yoga"
        case let s where s.contains("hike"):      return "figure.hiking"
        case let s where s.contains("row"):       return "figure.rower"
        default:                                  return "dumbbell.fill"
        }
    }
}
