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
    // DiaryEntry is intentionally `.nullify` — historical diary rows
    // should survive the deletion of their Food (user sees "Unknown"
    // for the food name; calories/macros persisted on the entry are
    // already denormalized via `DiaryEntry.totalCalories` etc., so the
    // row stays meaningful).
    //
    // FoodFavorite is `.cascade` because a favorite with no Food is
    // semantically empty — it's a bookmark with nothing bookmarked.
    // Previously this was `.nullify`, which would have left orphaned
    // FoodFavorite rows (and CloudKit records) if Food ever gets
    // deleted. No user-facing code path deletes Food today, but a
    // future "manage custom foods" flow or cross-device deletion
    // replication would hit this.
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
