import Foundation
import SwiftData
import SwiftUI

@Observable
final class MacrosViewModel {

    private var modelContext: ModelContext
    var profile: UserProfile

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            self.profile = existing
        } else {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            modelContext.saveOrLog("MacrosViewModel.init.createProfile")
            self.profile = newProfile
        }
    }

    // MARK: - Display Helpers

    var displayWeight: Double {
        profile.displayWeight
    }

    var displayHeight: Double {
        profile.displayHeight
    }

    // MARK: - Update Profile

    func updateProfile(
        weight: Double,
        height: Double,
        age: Int,
        gender: String,
        activityLevel: String,
        goal: String,
        unitSystem: String
    ) {
        profile.unitSystem = unitSystem
        profile.setWeight(fromDisplay: weight)
        profile.setHeight(fromDisplay: height)
        profile.age = age
        profile.gender = gender
        profile.activityLevel = activityLevel
        profile.goal = goal

        let bmr = MacroCalculator.calculateBMR(
            weightKg: profile.weight,
            heightCm: profile.height,
            age: profile.age,
            gender: profile.gender
        )
        let tdee = MacroCalculator.calculateTDEE(bmr: bmr, activityLevel: profile.activityLevel)
        let targets = MacroCalculator.calculateMacros(tdee: tdee, goal: profile.goal, weightKg: profile.weight)

        profile.tdee = tdee
        profile.calorieTarget = targets.calories
        profile.proteinTarget = targets.protein
        profile.carbTarget = targets.carbs
        profile.fatTarget = targets.fat
        profile.updatedAt = .now

        modelContext.saveOrLog("MacrosViewModel.updateProfile")
    }

    // MARK: - Preview (Stateless)

    func previewCalculation(
        weight: Double,
        height: Double,
        age: Int,
        gender: String,
        activityLevel: String,
        goal: String,
        unitSystem: String
    ) -> MacroTargets {
        let weightKg = unitSystem == "imperial" ? MacroCalculator.lbsToKg(weight) : weight
        let heightCm = unitSystem == "imperial" ? MacroCalculator.inchesToCm(height) : height

        let bmr = MacroCalculator.calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, gender: gender)
        let tdee = MacroCalculator.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
        return MacroCalculator.calculateMacros(tdee: tdee, goal: goal, weightKg: weightKg)
    }
}
