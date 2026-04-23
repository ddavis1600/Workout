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
    /// Maps to HKWorkoutActivityType on save. See HealthKitManager.hkActivityType(from:).
    /// Values: "strength" (default), "running", "cycling", "walking", "hiit", "yoga", "swimming", "other".
    var workoutType: String? = nil

    init(name: String = "", date: Date = Date(), notes: String = "", durationMinutes: Int? = nil, photoData: Data? = nil, workoutType: String? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.photoData = photoData
        self.workoutType = workoutType
        self.createdAt = Date()
    }
}
