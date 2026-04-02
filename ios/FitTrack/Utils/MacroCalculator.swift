import Foundation

struct MacroTargets {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct MacroCalculator {

    // MARK: - BMR (Mifflin-St Jeor)

    static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, gender: String) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return gender.lowercased() == "male" ? base + 5 : base - 161
    }

    // MARK: - TDEE

    static func calculateTDEE(bmr: Double, activityLevel: String) -> Double {
        let multiplier: Double
        switch activityLevel.lowercased() {
        case "sedentary":   multiplier = 1.2
        case "light":       multiplier = 1.375
        case "moderate":    multiplier = 1.55
        case "active":      multiplier = 1.725
        case "very_active": multiplier = 1.9
        default:            multiplier = 1.55
        }
        return bmr * multiplier
    }

    // MARK: - Macro Targets

    static func calculateMacros(tdee: Double, goal: String, weightKg: Double) -> MacroTargets {
        let adjustedCalories: Double
        switch goal.lowercased() {
        case "cut":      adjustedCalories = tdee - 500
        case "bulk":     adjustedCalories = tdee + 300
        default:         adjustedCalories = tdee
        }

        let protein = 2.2 * weightKg
        let fat = (adjustedCalories * 0.25) / 9.0
        let proteinCals = protein * 4.0
        let fatCals = fat * 9.0
        let carbs = (adjustedCalories - proteinCals - fatCals) / 4.0

        return MacroTargets(
            calories: adjustedCalories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }

    // MARK: - Unit Conversions

    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / 2.20462
    }

    static func kgToLbs(_ kg: Double) -> Double {
        kg * 2.20462
    }

    static func inchesToCm(_ inches: Double) -> Double {
        inches * 2.54
    }

    static func cmToInches(_ cm: Double) -> Double {
        cm / 2.54
    }
}
