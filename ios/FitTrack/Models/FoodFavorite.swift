import Foundation
import SwiftData

@Model
final class FoodFavorite {
    var food: Food?
    var createdAt: Date = Date()

    init(food: Food) {
        self.food = food
        self.createdAt = Date()
    }
}
