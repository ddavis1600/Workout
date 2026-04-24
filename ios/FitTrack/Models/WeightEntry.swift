import SwiftData
import Foundation

@Model
final class WeightEntry {
    var date: Date = Date()
    var weight: Double = 0    // stored in kg
    var note: String = ""

    /// Stable identifier of the underlying `HKQuantitySample` when this
    /// entry was imported from Apple Health. Nil for rows the user
    /// created manually in-app (and for any pre-existing rows from
    /// before this field existed).
    ///
    /// Used by `WeightTrackingView.importFromHealthKit` to deduplicate:
    /// if a sample with this UUID already exists we skip it, rather
    /// than the previous behavior of collapsing by calendar date
    /// (which silently dropped multiple weigh-ins on the same day and
    /// blocked HK-side edits from ever flowing back).
    ///
    /// Not marked `@Attribute(.unique)` on purpose — CloudKit doesn't
    /// allow `.unique`, and the import logic enforces uniqueness in app
    /// code. Optional + nil default keeps CloudKit happy.
    var healthKitUUID: UUID? = nil

    init(date: Date = .now, weight: Double, note: String = "", healthKitUUID: UUID? = nil) {
        self.date = date.startOfDay
        self.weight = weight
        self.note = note
        self.healthKitUUID = healthKitUUID
    }

    func displayWeight(unitSystem: String) -> Double {
        unitSystem == "imperial" ? weight * 2.20462 : weight
    }

    static func fromDisplay(_ value: Double, unitSystem: String) -> Double {
        unitSystem == "imperial" ? value / 2.20462 : value
    }
}
