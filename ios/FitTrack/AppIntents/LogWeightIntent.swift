import AppIntents
import SwiftData
import HealthKit

/// "Log my weight" — adds a `WeightEntry` and pushes the value to
/// Apple Health. Runs without opening the app (`openAppWhenRun: false`)
/// so a Siri tap can dispatch + dismiss. The HK write is best-effort:
/// if the user hasn't authorised the bodyMass share type yet, the
/// SwiftData entry still lands and HK sync deferred.
///
/// Imperial / metric is captured as a parameter rather than read from
/// `UserProfile.unitSystem` so a Shortcuts user can override per
/// invocation ("log my weight 165 lbs" vs "log my weight 75 kg") even
/// if their app default differs.
struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log My Weight"
    static let description = IntentDescription(
        "Records a weight entry in FitTrack and (if authorised) Apple Health."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Weight",
        description: "Your weight in the chosen units.",
        inclusiveRange: (1.0, 1000.0)
    )
    var weight: Double

    @Parameter(
        title: "Units",
        description: "Imperial (lb) or Metric (kg).",
        default: WeightUnitAppEntity.imperial
    )
    var units: WeightUnitAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Log my weight: \(\.$weight) \(\.$units)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Convert to kg for storage — matches WeightEntry / HKQuantity
        // conventions everywhere else in the app.
        let weightKg: Double = units == .imperial ? weight / 2.20462 : weight

        let container = try ModelContainer(
            for:
                Exercise.self, Workout.self, WorkoutSet.self,
                UserProfile.self, Food.self, DiaryEntry.self,
                Habit.self, HabitCompletion.self,
                WeightEntry.self, JournalEntry.self,
                WorkoutTemplate.self, TemplateExercise.self,
                BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self
        )
        try await MainActor.run {
            let context = ModelContext(container)
            let entry = WeightEntry(date: .now, weight: weightKg, note: "Logged via Shortcuts")
            context.insert(entry)
            try context.save()
        }

        // HK write is fire-and-forget. requestAuthorization is a
        // no-op if already granted; if denied, the call returns
        // false and we silently skip — the SwiftData entry still
        // exists and the user can see it on the Weight screen.
        Task {
            let hk = HealthKitManager.shared
            guard hk.isAvailable else { return }
            _ = await hk.requestAuthorization()
            await hk.saveWeight(weightKg, date: .now)
        }

        let displayWeight = units == .imperial ? weight : weight
        return .result(dialog: "Logged your weight at \(String(format: "%.1f", displayWeight)) \(units.shortLabel).")
    }
}

// MARK: - Units entity

enum WeightUnitAppEntity: String, AppEnum {
    case imperial, metric

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Weight Units")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .imperial: "Pounds (lb)",
        .metric:   "Kilograms (kg)",
    ]

    var shortLabel: String {
        self == .imperial ? "lb" : "kg"
    }
}
