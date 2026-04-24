import SwiftData
import Foundation

// MARK: - V1 Schema
//
// Frozen snapshot of the pre-CloudKit store shape. The nested `Habit` /
// `HabitCompletion` redeclarations below are intentional — by living
// inside the `SchemaV1` namespace they freeze the exact fields and
// relationship shape the original store had, so the V1→V2 migration
// stage has a stable `fromVersion` to point at even as the top-level
// `Habit` / `HabitCompletion` continue to evolve.
//
// The other models (Workout, WorkoutSet, Exercise, …) use the current
// top-level types directly. Their structural shape between V1 and V2
// is identical, so there's nothing to freeze — SwiftData fingerprints
// the type as it is today and the migration is a no-op for those.

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
//
// Current schema. Uses the top-level `Habit` / `HabitCompletion` types
// directly — whatever fields those have today is what V2 is.
//
// SwiftData's automatic lightweight migration covers every additive
// change made to the top-level models since V1 (e.g. optional fields
// with inline defaults for CloudKit compatibility). No SchemaV3 is
// needed for additive changes; we only bump the schema number when
// we need to change field semantics or drop a property outright.

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

// MARK: - Migration Plan

enum FitTrackMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self]
    static let stages: [MigrationStage] = [migrateV1toV2]

    // Adding a property with a default value is a lightweight (automatic) migration.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion:   SchemaV2.self
    )
}
