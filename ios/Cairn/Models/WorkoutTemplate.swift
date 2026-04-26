import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var name: String = ""
    @Relationship(deleteRule: .cascade) var exercises: [TemplateExercise]?
    var createdAt: Date = Date()

    init(name: String = "") {
        self.name = name
        self.createdAt = Date()
    }
}
