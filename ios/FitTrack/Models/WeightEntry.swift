import SwiftData
import Foundation

@Model
final class WeightEntry {
    var date: Date = .now
    var weight: Double = 0    // stored in kg
    var note: String = ""

    init(date: Date = .now, weight: Double, note: String = "") {
        self.date = date.startOfDay
        self.weight = weight
        self.note = note
    }

    func displayWeight(unitSystem: String) -> Double {
        unitSystem == "imperial" ? weight * 2.20462 : weight
    }

    static func fromDisplay(_ value: Double, unitSystem: String) -> Double {
        unitSystem == "imperial" ? value / 2.20462 : value
    }
}
