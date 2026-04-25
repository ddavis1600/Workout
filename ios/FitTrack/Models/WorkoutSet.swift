import Foundation
import SwiftData

@Model
final class WorkoutSet {
    @Relationship(inverse: \Exercise.workoutSets) var exercise: Exercise?
    /// CloudKit-required default. `0` is an unassigned sentinel — every
    /// real call site (`WorkoutPersistence`, `LogWorkoutView`,
    /// `WorkoutDetailView`) assigns `index + 1` explicitly when building
    /// a set. Using `1` as the default would silently produce a
    /// duplicate "Set #1" if a future caller ever forgot to pass a
    /// number; `0` makes the omission immediately visible in the UI
    /// and in exports.
    var setNumber: Int = 0
    var reps: Int?
    var weight: Double?
    var rpe: Double?
    var notes: String = ""
    @Relationship(inverse: \Workout.sets) var workout: Workout?

    init(exercise: Exercise? = nil, setNumber: Int, reps: Int? = nil, weight: Double? = nil, rpe: Double? = nil, notes: String = "") {
        self.exercise = exercise
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.notes = notes
    }
}
