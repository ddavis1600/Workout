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
    /// Distance covered in meters (canonical unit). Displayed as mi or km
    /// depending on UserProfile.unitSystem. Only meaningful for distance
    /// activities (running / cycling / walking / swimming).
    var distanceMeters: Double? = nil

    init(name: String = "", date: Date = Date(), notes: String = "", durationMinutes: Int? = nil, photoData: Data? = nil, workoutType: String? = nil, distanceMeters: Double? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.photoData = photoData
        self.workoutType = workoutType
        self.distanceMeters = distanceMeters
        self.createdAt = Date()
    }

    /// Whether a stored workoutType string represents a distance activity.
    static func isDistanceType(_ type: String?) -> Bool {
        ["running", "cycling", "walking", "swimming"].contains(type ?? "")
    }

    /// Formatted distance for display (e.g. "3.12 mi" or "5.02 km").
    /// Returns nil if no distance is recorded.
    func displayDistance(unitSystem: String) -> String? {
        guard let m = distanceMeters, m > 0 else { return nil }
        if unitSystem == "imperial" {
            let miles = m * 0.000621371
            return String(format: "%.2f mi", miles)
        } else {
            let km = m / 1000.0
            return String(format: "%.2f km", km)
        }
    }
}
