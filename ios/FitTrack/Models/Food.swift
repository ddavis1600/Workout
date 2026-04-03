import Foundation
import SwiftData

@Model
final class Food {
    var name: String = ""
    var brand: String?
    var servingSize: Double = 0
    var servingUnit: String = "g"
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var isCustom: Bool = false

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
