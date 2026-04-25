import AppIntents

/// Registers all five App Intents with the system so they surface
/// in Spotlight, the Shortcuts app, and Siri Suggestions
/// automatically (audit ref F4).
///
/// Each `AppShortcut` pairs an `AppIntent` with one or more
/// invocation phrases. The `.applicationName` token in each phrase
/// resolves to the user-facing app name ("FitTrack") at runtime,
/// so phrases stay correct even if the app is rebranded later.
///
/// Tile color falls back to the system default. The
/// `ShortcutTileColor` palette is constrained and doesn't include
/// a green close enough to the in-app emerald accent to be worth
/// pinning.
struct FitTrackShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        // Phrase substitutions can only reference AppEntity/AppEnum
        // parameters, so the `workoutType: String` parameter doesn't
        // appear inline. Siri prompts for it after recognition.
        AppShortcut(
            intent: LogWorkoutIntent(),
            phrases: [
                "Log a workout in \(.applicationName)",
                "Start a workout in \(.applicationName)",
            ],
            shortTitle: "Log Workout",
            systemImageName: "dumbbell.fill"
        )

        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log a meal in \(.applicationName)",
                "Log \(\.$mealType) in \(.applicationName)",
            ],
            shortTitle: "Log Meal",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Track weight in \(.applicationName)",
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass.fill"
        )

        // `habitName: String` is also non-substitutable here. Siri
        // prompts for it after recognising the verb.
        AppShortcut(
            intent: LogHabitIntent(),
            phrases: [
                "Mark a habit complete in \(.applicationName)",
                "Complete a habit in \(.applicationName)",
            ],
            shortTitle: "Mark Habit Done",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: StopWorkoutIntent(),
            phrases: [
                "Stop my workout in \(.applicationName)",
                "End workout in \(.applicationName)",
            ],
            shortTitle: "Stop Workout",
            systemImageName: "stop.fill"
        )
    }
}
