import AppIntents
import SwiftData

/// "Mark habit complete" — toggles a habit's completion for today.
/// Surfaces via Siri ("Hey Siri, mark Drink Water complete in
/// FitTrack") and Shortcuts.
///
/// The user provides the habit by name. We do a fuzzy
/// case-insensitive match — `localizedCaseInsensitiveCompare` for
/// exact, then `localizedCaseInsensitiveContains` as a fallback.
/// If multiple habits match, the first by sortOrder wins so the
/// behavior is deterministic across invocations.
///
/// `openAppWhenRun: false` matches `LogFoodIntent` / `LogWeightIntent` —
/// a successful complete shouldn't pull the user into the app.
struct LogHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Habit Complete"
    static let description = IntentDescription(
        "Marks a FitTrack habit complete for today."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Habit Name",
        description: "The habit to mark complete."
    )
    var habitName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$habitName) complete")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(
            for:
                Exercise.self, Workout.self, WorkoutSet.self,
                UserProfile.self, Food.self, DiaryEntry.self,
                Habit.self, HabitCompletion.self,
                WeightEntry.self, JournalEntry.self,
                WorkoutTemplate.self, TemplateExercise.self,
                BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self
        )
        let foundName: String? = try await MainActor.run {
            let context = ModelContext(container)
            let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
            // Exact (case-insensitive) match first, then substring.
            let needle = habitName
            let exact = habits.first { $0.name.localizedCaseInsensitiveCompare(needle) == .orderedSame }
            let fuzzy = habits
                .filter { $0.name.localizedCaseInsensitiveContains(needle) }
                .sorted { $0.sortOrder < $1.sortOrder }
                .first
            guard let habit = exact ?? fuzzy else { return nil }
            // Toggle is idempotent in the user-experience sense:
            // if today's completion already exists, the existing
            // `Habit.toggle(on:context:)` will remove it. For an
            // intent flow, we want "ensure complete" semantics —
            // skip the toggle if already done.
            let cal = Calendar.current
            let alreadyDone = (habit.completions ?? []).contains {
                cal.isDate($0.date, inSameDayAs: .now)
            }
            if !alreadyDone {
                habit.toggle(on: .now, context: context)
            }
            return habit.name
        }

        if let name = foundName {
            return .result(dialog: "Marked \"\(name)\" complete for today.")
        } else {
            return .result(dialog: "Couldn't find a habit matching \"\(habitName)\".")
        }
    }
}
