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

// MARK: - V2 Schema (current)
// Habit gains `uuid: UUID = UUID()`. Also picks up any additive optional
// fields added to the top-level @Model classes since V2 was minted — the
// current ones being:
//   • HabitCompletion.note: String?
//   • Workout.workoutType: String?
//   • Workout.distanceMeters: Double?
//   • Workout.elevationGainMeters: Double?
//   • Workout.routeData: Data?
// SwiftData's automatic inferred lightweight migration handles adding
// these columns to on-disk stores that were last written with an earlier
// shape of SchemaV2 — no explicit migration stage required.
//
// We previously also declared SchemaV3 for "clarity"; that caused a
// `Duplicate version checksums detected` crash at launch because V2 and
// V3 referenced the same live classes and therefore hashed identically.
// Schemas must differ structurally to co-exist in a SchemaMigrationPlan.

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
    static let schemas: [any VersionedSchema.Type] = [
        SchemaV1.self, SchemaV2.self,
    ]
    static let stages: [MigrationStage] = [migrateV1toV2]

    // Adding a property with a default value is a lightweight (automatic) migration.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion:   SchemaV2.self
    )
}
