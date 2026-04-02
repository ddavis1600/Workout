import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var date: Date
    var mealType: String
    var food: Food?
    var servings: Double
    var createdAt: Date

    var totalCalories: Double {
        (food?.calories ?? 0) * servings
    }

    var totalProtein: Double {
        (food?.protein ?? 0) * servings
    }

    var totalCarbs: Double {
        (food?.carbs ?? 0) * servings
    }

    var totalFat: Double {
        (food?.fat ?? 0) * servings
    }

    init(date: Date = .now, mealType: String, food: Food? = nil, servings: Double = 1.0) {
        self.date = date
        self.mealType = mealType
        self.food = food
        self.servings = servings
        self.createdAt = .now
    }
}
