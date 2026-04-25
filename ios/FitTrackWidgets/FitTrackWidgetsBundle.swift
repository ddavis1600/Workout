import WidgetKit
import SwiftUI

/// Entry point for the FitTrack Home Screen widget extension.
///
/// Bundle now hosts:
///   - **Today's Stats** (small + medium): calories in/out + steps. (P6 F1)
///   - **Streak** (small): longest current habit streak with a flame
///     visual. (P6 F1)
///   - **Today's Workout** (medium): today's logged workout name +
///     duration, or a "log a workout" CTA empty-state. (P6 F1)
///   - **Workout Live Activity**: lock-screen + Dynamic Island
///     surface for the active workout session. (P8 F3)
///
/// Static widgets read from the shared `WidgetSnapshot` JSON written
/// by the main app to the App Group `UserDefaults` suite. The Live
/// Activity is push-driven via `LiveActivityManager` — the main app
/// updates state every ~5 s during a workout and ends it on Save.
@main
struct FitTrackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayStatsWidget()
        StreakWidget()
        TodayWorkoutWidget()
        WorkoutLiveActivity()
    }
}
