import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var exercise: Exercise?
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var rpe: Double?
    var notes: String
    @Relationship(inverse: \Workout.sets) var workout: Workout?

    init(exercise: Exercise? = nil, setNumber: Int = 1, reps: Int? = nil, weight: Double? = nil, rpe: Double? = nil, notes: String = "") {
        self.exercise = exercise
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.notes = notes
    }
}
