import Foundation
import SwiftData
import SwiftUI

@Observable
final class DiaryViewModel {

    private var modelContext: ModelContext

    var selectedDate: Date = Date.now.startOfDay
    var entries: [DiaryEntry] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchEntries()
    }

    // MARK: - Computed

    var entriesByMeal: [String: [DiaryEntry]] {
        Dictionary(grouping: entries, by: { $0.mealType })
    }

    var totalCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    var totalProtein: Double {
        entries.reduce(0) { $0 + $1.totalProtein }
    }

    var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.totalCarbs }
    }

    var totalFat: Double {
        entries.reduce(0) { $0 + $1.totalFat }
    }

    /// Carbs minus fiber across all entries today
    var totalNetCarbs: Double {
        entries.reduce(0) { $0 + $1.totalNetCarbs }
    }

    // MARK: - Fetching

    func fetchEntries() {
        let start = selectedDate.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Mutations

    func addEntry(food: Food, mealType: String, servings: Double) {
        let entry = DiaryEntry(date: selectedDate, mealType: mealType, food: food, servings: servings)
        modelContext.insert(entry)
        try? modelContext.save()
        fetchEntries()
    }

    func deleteEntry(_ entry: DiaryEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        fetchEntries()
    }

    func updateServings(_ entry: DiaryEntry, servings: Double) {
        entry.servings = servings
        try? modelContext.save()
        fetchEntries()
    }

    // MARK: - Search

    func searchFoods(query: String) -> [Food] {
        guard !query.isEmpty else {
            let descriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
            return (try? modelContext.fetch(descriptor)) ?? []
        }
        let descriptor = FetchDescriptor<Food>(
            predicate: #Predicate<Food> { food in
                food.name.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
