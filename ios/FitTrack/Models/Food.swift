import Foundation
import SwiftData

@Model
final class Food {
    var name: String
    var brand: String?
    var servingSize: Double
    var servingUnit: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var isCustom: Bool

    init(
        name: String,
        servingSize: Double,
        servingUnit: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        brand: String? = nil,
        isCustom: Bool = false
    ) {
        self.name = name
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.brand = brand
        self.isCustom = isCustom
    }
}
