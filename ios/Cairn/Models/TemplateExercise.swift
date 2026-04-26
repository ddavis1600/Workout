import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var exerciseName: String = ""
    var muscleGroup: String = ""
    var defaultSets: Int = 3
    var defaultReps: Int = 10
    var defaultWeight: Double = 0
    var sortOrder: Int = 0
    @Relationship(inverse: \WorkoutTemplate.exercises) var template: WorkoutTemplate?

    init(exerciseName: String = "", muscleGroup: String = "", defaultSets: Int = 3, defaultReps: Int = 10, defaultWeight: Double = 0, sortOrder: Int = 0) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
        self.sortOrder = sortOrder
    }
}
