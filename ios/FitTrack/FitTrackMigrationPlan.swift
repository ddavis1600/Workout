import SwiftData
import Foundation

// MARK: - V1 Schema
// State of the store before `uuid: UUID` was added to Habit.
// HabitCompletion is redefined here (within the same namespace) so that
// the Habit.completions relationship can refer to the V1 version without
// creating a cross-version type reference.

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        SchemaV1.Habit.self,
        SchemaV1.HabitCompletion.self,
        Workout.self, WorkoutSet.self, Exercise.self,
        UserProfile.self, Food.self, DiaryEntry.self,
        WeightEntry.self, JournalEntry.self,
        WorkoutTemplate.self, TemplateExercise.self,
        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
    ]

    @Model
    final class Habit {
        var name: String = ""
        var icon: String = "checkmark.circle"
        var color: String = "emerald"
        var createdAt: Date = Date()
        var healthKitTrigger: String?
        var healthKitThreshold: Double = 0
        var scheduledDays: [Int] = []
        var reminderTime: Date?
        var weeklyTarget: Int = 7
        var category: String = "Custom"
        var sortOrder: Int = 0
        var earnedBadges: [Int] = []
        var freezeAppliedDates: [Date] = []
        // Refers to SchemaV1.HabitCompletion via Swift scoping rules
        @Relationship(deleteRule: .cascade) var completions: [HabitCompletion] = []

        init() {}
    }

    @Model
    final class HabitCompletion {
        var date: Date = Date()
        // Inverse inferred by SwiftData from Habit.completions
        var habit: Habit?

        init() {}
    }
}

// MARK: - V2 Schema
// Habit gains `uuid: UUID = UUID()`.

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static let models: [any PersistentModel.Type] = [
        Habit.self, HabitCompletion.self,
        Workout.self, WorkoutSet.self, Exercise.self,
        UserProfile.self, Food.self, DiaryEntry.self,
        WeightEntry.self, JournalEntry.self,
        WorkoutTemplate.self, TemplateExercise.self,
        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
    ]
}

// MARK: - V3 Schema
// Current schema — adds two optional properties (lightweight migration):
//   • HabitCompletion.note: String?  (per-day note on a habit check-in)
//   • Workout.workoutType: String?   (maps to HKWorkoutActivityType on save)
// Both additions are Optional, so they're CloudKit-safe and handled by
// SwiftData's automatic lightweight migration from V2.

enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static let models: [any PersistentModel.Type] = [
        Habit.self, HabitCompletion.self,
        Workout.self, WorkoutSet.self, Exercise.self,
        UserProfile.self, Food.self, DiaryEntry.self,
        WeightEntry.self, JournalEntry.self,
        WorkoutTemplate.self, TemplateExercise.self,
        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
    ]
}

// MARK: - Migration Plan

enum FitTrackMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SchemaV1.self, SchemaV2.self, SchemaV3.self,
    ]
    static let stages: [MigrationStage] = [migrateV1toV2, migrateV2toV3]

    // Adding a property with a default value is a lightweight (automatic) migration.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion:   SchemaV2.self
    )

    // Adds HabitCompletion.note and Workout.workoutType — both optional.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion:   SchemaV3.self
    )
}
