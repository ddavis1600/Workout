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
    var fiber: Double = 0
    var isCustom: Bool = false
    // Inverse relationships required by CloudKit.
    //
    // DiaryEntry stays `.nullify` — historical diary rows should
    // survive deletion of their Food. The macro/calorie totals are
    // already denormalized on `DiaryEntry` so the row stays
    // meaningful; UI shows "Unknown" for the food name.
    //
    // FoodFavorite is `.cascade` because a favorite with no Food is
    // semantically empty — a bookmark with nothing bookmarked.
    // Previously `.nullify`, which would have left orphaned rows
    // (and CloudKit records) if Food ever gets deleted. No code
    // path deletes Food today, but a future "manage custom foods"
    // flow or cross-device deletion replication would hit this.
    @Relationship(deleteRule: .nullify) var diaryEntries: [DiaryEntry]?
    @Relationship(deleteRule: .cascade) var foodFavorites: [FoodFavorite]?

    init(
        name: String,
        servingSize: Double,
        servingUnit: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
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
        self.fiber = fiber
        self.brand = brand
        self.isCustom = isCustom
    }
}
