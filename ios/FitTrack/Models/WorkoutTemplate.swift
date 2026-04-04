import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var name: String = ""
    @Relationship(deleteRule: .cascade) var exercises: [TemplateExercise] = []
    var createdAt: Date = Date()

    init(name: String = "", exercises: [TemplateExercise] = []) {
        self.name = name
        self.exercises = exercises
        self.createdAt = Date()
    }
}
