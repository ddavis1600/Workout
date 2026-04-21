import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var date: Date = Date()
    var mealType: String = "breakfast"
    @Relationship(inverse: \Food.diaryEntries) var food: Food?
    var servings: Double = 1.0
    var createdAt: Date = Date()
    var healthKitCorrelationID: UUID? = nil

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

    var totalFiber: Double {
        (food?.fiber ?? 0) * servings
    }

    var totalNetCarbs: Double {
        max(0, totalCarbs - totalFiber)
    }

    init(date: Date = .now, mealType: String, food: Food? = nil, servings: Double = 1.0) {
        self.date = date
        self.mealType = mealType
        self.food = food
        self.servings = servings
        self.createdAt = .now
    }
}
