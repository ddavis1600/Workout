import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var date: Date
    var notes: String
    var durationMinutes: Int?
    @Attribute(.externalStorage) var photoData: Data?
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet]
    var createdAt: Date

    init(name: String = "", date: Date = .now, notes: String = "", durationMinutes: Int? = nil, photoData: Data? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.photoData = photoData
        self.sets = []
        self.createdAt = .now
    }
}
