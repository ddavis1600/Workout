import Foundation
import SwiftData

@Model
final class UserProfile {
    var weight: Double = 70.0
    var height: Double = 175.0
    var age: Int = 25
    var gender: String = "male"
    var activityLevel: String = "moderate"
    var goal: String = "maintain"
    var tdee: Double = 0
    var proteinTarget: Double = 0
    var carbTarget: Double = 0
    var fatTarget: Double = 0
    var calorieTarget: Double = 0
    var unitSystem: String = "imperial"
    var updatedAt: Date = Date()

    init() {
        self.weight = 70.0
        self.height = 175.0
        self.age = 25
        self.gender = "male"
        self.activityLevel = "moderate"
        self.goal = "maintain"
        self.tdee = 0
        self.proteinTarget = 0
        self.carbTarget = 0
        self.fatTarget = 0
        self.calorieTarget = 0
        self.unitSystem = "imperial"
        self.updatedAt = .now
    }

    /// Recalculates TDEE and macro targets based on current profile values.
    func recalculateMacros() {
        // Mifflin-St Jeor equation
        let bmr: Double
        if gender == "male" {
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        } else {
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        }

        let multiplier: Double
        switch activityLevel {
        case "sedentary":    multiplier = 1.2
        case "light":        multiplier = 1.375
        case "moderate":     multiplier = 1.55
        case "active":       multiplier = 1.725
        case "very_active":  multiplier = 1.9
        default:             multiplier = 1.55
        }

        tdee = bmr * multiplier

        switch goal {
        case "cut":      calorieTarget = tdee - 500
        case "bulk":     calorieTarget = tdee + 300
        default:         calorieTarget = tdee
        }

        // Protein: 1g per lb of bodyweight (2.2g/kg)
        proteinTarget = weight * 2.2

        // Fat: 25% of calories
        fatTarget = (calorieTarget * 0.25) / 9.0

        // Carbs: remaining calories
        let proteinCals = proteinTarget * 4.0
        let fatCals = fatTarget * 9.0
        carbTarget = (calorieTarget - proteinCals - fatCals) / 4.0

        updatedAt = .now
    }

    // MARK: - Unit Conversions

    /// Weight displayed in the user's chosen unit system.
    var displayWeight: Double {
        unitSystem == "imperial" ? weight * 2.20462 : weight
    }

    /// Height displayed in the user's chosen unit system (inches for imperial).
    var displayHeight: Double {
        unitSystem == "imperial" ? height / 2.54 : height
    }

    /// Sets weight from a value in the user's chosen unit system.
    func setWeight(fromDisplay value: Double) {
        weight = unitSystem == "imperial" ? value / 2.20462 : value
    }

    /// Sets height from a value in the user's chosen unit system.
    func setHeight(fromDisplay value: Double) {
        height = unitSystem == "imperial" ? value * 2.54 : value
    }
}
