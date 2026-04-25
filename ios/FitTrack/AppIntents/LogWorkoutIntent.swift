import AppIntents
import SwiftData

/// "Log a workout" — opens the app to a pre-filled workout entry
/// with the requested type and duration. Surfaces in Spotlight,
/// the Shortcuts app, and Siri ("Hey Siri, log a 30-minute run in
/// FitTrack") via the AppShortcutsProvider registration.
///
/// Why `openAppWhenRun = true`: writing a Workout from a cold-start
/// intent process is doable but loses the user's choice of name /
/// notes / sets. Better to deposit them in `LogWorkoutView` with
/// the type + duration pre-populated and let them confirm + extend.
/// The runner can paste the supplied parameters into UserDefaults
/// keys that `LogWorkoutView` reads on appear.
struct LogWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Workout"
    static let description = IntentDescription(
        "Opens FitTrack with a new workout pre-populated with your chosen type and duration."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Workout Type",
        description: "Running, Cycling, Strength, Yoga, etc.",
        default: "Strength"
    )
    var workoutType: String

    @Parameter(
        title: "Duration (minutes)",
        description: "How long was the workout?",
        default: 30,
        inclusiveRange: (1, 600)
    )
    var durationMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$durationMinutes)-minute \(\.$workoutType) workout")
    }

    /// Hands the parameters to the main app via UserDefaults under
    /// well-known keys. `LogWorkoutView` reads these on appear and
    /// pre-fills the name + duration fields, then clears the keys.
    /// Cleaner than introducing a custom URL scheme just for this
    /// hand-off, and works without the app being foregrounded yet.
    @MainActor
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(workoutType, forKey: "pendingIntent_workoutType")
        defaults.set(durationMinutes, forKey: "pendingIntent_workoutDuration")
        return .result()
    }
}
