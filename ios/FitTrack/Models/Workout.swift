import Foundation
import SwiftData

@Model
final class Workout {
    var name: String = ""
    var date: Date = Date()
    var notes: String = ""
    var durationMinutes: Int?
    var photoData: Data?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var minHeartRate: Int?
    var hrZone1Seconds: Double?
    var hrZone2Seconds: Double?
    var hrZone3Seconds: Double?
    var hrZone4Seconds: Double?
    var hrZone5Seconds: Double?
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet]?
    var createdAt: Date = Date()

    /// Maps to `HKWorkoutActivityType` on save.
    /// Values: "strength" (default), "running", "cycling", "walking",
    /// "hiit", "yoga", "swimming", "other". Stored as a tag string
    /// rather than an enum so future activity kinds (e.g. "rowing")
    /// can be added without a schema bump.
    ///
    /// Optional with `nil` default so SwiftData performs a lightweight
    /// inferred migration on existing stores — workouts written before
    /// this field existed simply have `workoutType == nil`, which the
    /// HK save path treats as `.traditionalStrengthTraining`.
    var workoutType: String? = nil

    init(
        name: String = "",
        date: Date = Date(),
        notes: String = "",
        durationMinutes: Int? = nil,
        photoData: Data? = nil,
        workoutType: String? = nil
    ) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.photoData = photoData
        self.workoutType = workoutType
        self.createdAt = Date()
    }
}
