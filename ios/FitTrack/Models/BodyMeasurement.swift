import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var date: Date = Date()
    var chest: Double?
    var waist: Double?
    var hips: Double?
    var bicepLeft: Double?
    var bicepRight: Double?
    var thighLeft: Double?
    var thighRight: Double?
    var neck: Double?
    var shoulders: Double?
    var bodyFatPercent: Double?
    var createdAt: Date = Date()

    init(date: Date = Date()) {
        self.date = date
        self.createdAt = Date()
    }
}
