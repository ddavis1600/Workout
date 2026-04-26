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
        modelContext.saveOrLog("DiaryViewModel.addEntry")
        fetchEntries()
        WidgetSnapshot.refresh(from: modelContext)
        writeToHealthKit(entry: entry)
    }

    func deleteEntry(_ entry: DiaryEntry) {
        let correlationID = entry.healthKitCorrelationID
        modelContext.delete(entry)
        modelContext.saveOrLog("DiaryViewModel.deleteEntry")
        fetchEntries()
        WidgetSnapshot.refresh(from: modelContext)
        if let id = correlationID {
            Task { await HealthKitManager.shared.deleteFoodEntry(correlationID: id) }
        }
    }

    func updateServings(_ entry: DiaryEntry, servings: Double) {
        entry.servings = servings
        modelContext.saveOrLog("DiaryViewModel.updateServings")
        fetchEntries()
        WidgetSnapshot.refresh(from: modelContext)
        writeToHealthKit(entry: entry, existingCorrelationID: entry.healthKitCorrelationID)
    }

    private func writeToHealthKit(entry: DiaryEntry, existingCorrelationID: UUID? = nil) {
        let date = entry.date
        let mealType = entry.mealType
        let foodName = entry.food?.name ?? ""
        let calories = entry.totalCalories
        let protein = entry.totalProtein
        let carbs = entry.totalCarbs
        let fat = entry.totalFat
        let fiber = entry.totalFiber

        Task { @MainActor in
            let newID = await HealthKitManager.shared.updateFoodEntry(
                existingCorrelationID: existingCorrelationID,
                date: date, mealType: mealType, foodName: foodName,
                calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber
            )
            entry.healthKitCorrelationID = newID
            modelContext.saveOrLog("DiaryViewModel.writeToHealthKit")
        }
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
