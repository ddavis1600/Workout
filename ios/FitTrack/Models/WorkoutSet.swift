import Foundation
import SwiftData

@Model
final class WorkoutSet {
    @Relationship(inverse: \Exercise.workoutSets) var exercise: Exercise?

    /// 1-based position within a workout's set list. `0` is a sentinel
    /// for "unassigned" — a row inserted programmatically without the
    /// caller choosing an explicit position (e.g. a future import or
    /// backfill path that forgets).
    ///
    /// Previously defaulted to `1`, which meant any such accidental
    /// insert silently collided with the real set #1 — no error,
    /// no way to tell the unassigned row apart from a legitimate set.
    /// Now valid inserts are guaranteed to go through the
    /// `setNumber:` init parameter (it has no default), and the stored
    /// property keeps its CloudKit-required default as the sentinel.
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
