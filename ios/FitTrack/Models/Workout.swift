import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var date: Date
    var notes: String
    var durationMinutes: Int?
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet]
    var createdAt: Date

    init(name: String = "", date: Date = .now, notes: String = "", durationMinutes: Int? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.sets = []
        self.createdAt = .now
    }
}
