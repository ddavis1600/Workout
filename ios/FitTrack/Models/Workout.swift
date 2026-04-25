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
    /// Total positive elevation gain in meters during the workout. Computed
    /// from CLLocation.altitude deltas on the watch during live tracking.
    var elevationGainMeters: Double? = nil
    /// JSON-encoded array of RoutePoint values captured from CoreLocation
    /// on the watch. Stored as Data rather than a relationship so it survives
    /// CloudKit sync and iPhone-only installs. Decode with
    /// `Workout.decodedRoute` for MapKit display.
    var routeData: Data? = nil

    init(name: String = "", date: Date = Date(), notes: String = "", durationMinutes: Int? = nil, photoData: Data? = nil, workoutType: String? = nil, distanceMeters: Double? = nil, elevationGainMeters: Double? = nil, routeData: Data? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.photoData = photoData
        self.workoutType = workoutType
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.routeData = routeData
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

    /// Formatted average pace (e.g. "9:05 /mi" or "5:30 /km"). Needs both
    /// distance and duration. Returns nil if either is missing or zero.
    func displayPace(unitSystem: String) -> String? {
        guard let m = distanceMeters, m > 0,
              let minutes = durationMinutes, minutes > 0 else { return nil }
        let distanceInUnits = unitSystem == "imperial"
            ? m * 0.000621371   // miles
            : m / 1000.0        // km
        guard distanceInUnits > 0 else { return nil }
        let paceMinutesPerUnit = Double(minutes) / distanceInUnits
        let paceMin = Int(paceMinutesPerUnit)
        let paceSec = Int((paceMinutesPerUnit - Double(paceMin)) * 60)
        let unit = unitSystem == "imperial" ? "mi" : "km"
        return String(format: "%d:%02d /%@", paceMin, paceSec, unit)
    }

    /// Formatted elevation gain (e.g. "142 ft" or "43 m"). Returns nil if
    /// none recorded.
    func displayElevationGain(unitSystem: String) -> String? {
        guard let m = elevationGainMeters, m > 0 else { return nil }
        if unitSystem == "imperial" {
            let feet = m * 3.28084
            return String(format: "%d ft", Int(feet.rounded()))
        } else {
            return String(format: "%d m", Int(m.rounded()))
        }
    }

    /// Decoded route points, ready for MapKit display. Returns empty if
    /// routeData is nil or malformed.
    var decodedRoute: [RoutePoint] {
        guard let data = routeData,
              let points = try? JSONDecoder().decode([RoutePoint].self, from: data) else {
            return []
        }
        return points
    }
}

// MARK: - Route

/// One sample from the CoreLocation stream captured on the watch.
/// Encoded as JSON into Workout.routeData. Field names are short to keep
/// the serialized payload compact (long routes can accumulate thousands
/// of points over a multi-hour ride).
struct RoutePoint: Codable, Hashable {
    let lat: Double
    let lon: Double
    let alt: Double?
    let t: TimeInterval  // seconds since 1970
}
