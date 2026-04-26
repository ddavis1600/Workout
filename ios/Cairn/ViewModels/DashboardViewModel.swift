import Foundation
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    private let modelContext: ModelContext

    var recentWorkouts: [Workout] = []
    var todayEntries: [DiaryEntry] = []
    var profile: UserProfile?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        fetchRecentWorkouts()
        fetchTodayEntries()
        fetchProfile()
    }

    private func fetchRecentWorkouts() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 5
        recentWorkouts = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchTodayEntries() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= start && entry.date < end
        }
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
        todayEntries = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        profile = try? modelContext.fetch(descriptor).first
    }

    var todaysSummary: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        (
            calories: todayEntries.reduce(0) { $0 + $1.totalCalories },
            protein: todayEntries.reduce(0) { $0 + $1.totalProtein },
            carbs: todayEntries.reduce(0) { $0 + $1.totalCarbs },
            fat: todayEntries.reduce(0) { $0 + $1.totalFat }
        )
    }

    // Convenience accessors
    var todayCalories: Double { todaysSummary.calories }
    var todayProtein: Double { todaysSummary.protein }
    var todayCarbs: Double { todaysSummary.carbs }
    var todayFat: Double { todaysSummary.fat }
}
