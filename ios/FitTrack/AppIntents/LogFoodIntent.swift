import AppIntents
import SwiftData

/// "Log a meal" — appends a `DiaryEntry` for the requested meal type
/// without opening the app. Surfaces in Spotlight / Shortcuts / Siri
/// ("Hey Siri, log breakfast in FitTrack: 320 calories, oatmeal").
///
/// The intent runs in its own process, so the SwiftData write needs
/// a fresh `ModelContainer` rather than the main app's. Keeping the
/// container creation inline (rather than going through the app's
/// CloudKit-aware `FitTrackApp.init`) means an intent invocation
/// from the lock screen doesn't pay the CloudKit-handshake latency;
/// the synced entry will land in the user's iCloud database on the
/// next device sync.
struct LogFoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Meal"
    static let description = IntentDescription(
        "Adds a meal to FitTrack's food diary without opening the app."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Meal Type",
        description: "Breakfast, Lunch, Dinner, or Snack."
    )
    var mealType: MealTypeAppEntity

    @Parameter(
        title: "Food Name",
        description: "What did you eat?"
    )
    var foodName: String

    @Parameter(
        title: "Calories",
        description: "Estimated calories.",
        default: 0,
        inclusiveRange: (0, 5000)
    )
    var calories: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$foodName) for \(\.$mealType) (\(\.$calories) kcal)")
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
        // Hop to the main actor for the actual SwiftData mutation.
        // The model context is non-Sendable so the work has to
        // happen on a single actor; main actor matches what the
        // app uses elsewhere.
        try await MainActor.run {
            let context = ModelContext(container)
            // Synthesize a Food row for the entry. Marked `isCustom`
            // so it shows up in the user's library next time they
            // open the diary; a future pass can de-dupe by name.
            let food = Food(
                name: foodName,
                servingSize: 1,
                servingUnit: "serving",
                calories: Double(calories),
                protein: 0, carbs: 0, fat: 0, fiber: 0,
                isCustom: true
            )
            context.insert(food)

            let entry = DiaryEntry(
                date: .now,
                mealType: mealType.rawValue,
                food: food,
                servings: 1
            )
            context.insert(entry)
            try context.save()
        }

        return .result(dialog: "Logged \(foodName) for \(mealType.title).")
    }
}

// MARK: - Meal type entity (Siri/Shortcuts-friendly)

/// Wraps the diary's lowercased mealType strings as an AppEntity so
/// Shortcuts can present a tappable picker rather than a free-text
/// box. Mirrors `DiaryView.mealTypes` order.
enum MealTypeAppEntity: String, AppEnum {
    case breakfast, lunch, dinner, snack

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Meal Type"
    )
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .breakfast: "Breakfast",
        .lunch:     "Lunch",
        .dinner:    "Dinner",
        .snack:     "Snack",
    ]

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        }
    }
}
