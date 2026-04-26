import WidgetKit
import SwiftUI

/// Entry point for the Cairn Home Screen widget extension.
///
/// Three widgets ship in this bundle (audit ref F1):
///   - **Today's Stats** (small + medium): calories in/out + steps.
///   - **Streak** (small): longest current habit streak with a flame
///     visual.
///   - **Today's Workout** (medium): today's logged workout name +
///     duration, or a "log a workout" CTA empty-state.
///
/// All three read from the shared `WidgetSnapshot` JSON written by the
/// main app to the App Group `UserDefaults` suite. Timeline policy is
/// `.atEnd` with a 30-minute refresh, matching the spec — fresh data
/// also flows through `WidgetCenter.shared.reloadAllTimelines()` calls
/// on the main app's save paths, so most updates are immediate.
@main
struct CairnWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayStatsWidget()
        StreakWidget()
        TodayWorkoutWidget()
    }
}
