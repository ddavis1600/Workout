import AppIntents
import ActivityKit

/// Ends an in-progress workout from outside the app process.
///
/// Two call sites:
///   1. The Live Activity's expanded Dynamic Island Stop button —
///      `Button(intent: StopWorkoutIntent())` triggers this from
///      the widget extension process. The intent ends the
///      `Activity<WorkoutActivityAttributes>` directly via
///      ActivityKit (no SwiftData touch), so it can run cold
///      without main-app launch.
///   2. The Shortcuts app and Siri ("Hey Siri, stop my workout").
///
/// Why no SwiftData write: the intent has to ship in the widget
/// extension target alongside `WorkoutLiveActivity` so the
/// expanded-island button compiles. The widget extension doesn't
/// link the @Model classes, so the intent stays SwiftData-free
/// and only ends the Activity. Persisting the partial workout to
/// SwiftData requires the user to open the app and tap Save in
/// `LogWorkoutView`; the running app observes that Activity has
/// ended and updates its UI on next foreground.
///
/// `openAppWhenRun` is true so a Stop tap from the lock-screen
/// brings the user back into the app to confirm save / discard —
/// matches the Apple-Fitness "End Workout" UX.
struct StopWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Workout"
    static let description = IntentDescription(
        "Ends the active FitTrack workout. The app will open so you can save or discard the session."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // ActivityKit lookup — find any in-progress workout
        // activity and end it immediately. There should only ever
        // be one (LiveActivityManager's start path guards against
        // double-starts), but iterating is defensive.
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
