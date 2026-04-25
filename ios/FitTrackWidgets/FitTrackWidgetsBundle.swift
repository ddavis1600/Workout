import WidgetKit
import SwiftUI

/// Widget extension entry point. Right now this hosts only the
/// active-workout Live Activity (audit ref F3). When P6's Home
/// Screen widget set merges in, the three static widgets
/// (Today's Stats, Streak, Today's Workout) join this bundle.
///
/// Both targets must declare the same App Group ID in their
/// entitlements; ActivityKit doesn't strictly require it but
/// future Home Screen widgets will, and keeping the entitlement
/// on the extension now means no second pbxproj round-trip later.
@main
struct FitTrackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
