import SwiftData
import Foundation

@Model
final class Habit {
    var name: String = ""
    var icon: String = "checkmark.circle"
    var color: String = "emerald"
    var createdAt: Date = Date()
    /// Optional HealthKit trigger identifier (e.g. "stepCount", "activeEnergyBurned", …)
    var healthKitTrigger: String?
    /// Daily threshold to satisfy the HealthKit trigger (steps, kcal, minutes, etc.)
    var healthKitThreshold: Double = 0
    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]

    init(name: String, icon: String = "checkmark.circle", color: String = "emerald",
         healthKitTrigger: String? = nil, healthKitThreshold: Double = 0) {
        self.name = name
        self.icon = icon
        self.color = color
        self.healthKitTrigger = healthKitTrigger
        self.healthKitThreshold = healthKitThreshold
        self.createdAt = .now
        self.completions = []
    }

    func isCompleted(on date: Date) -> Bool {
        completions.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func toggle(on date: Date, context: ModelContext) {
        if let existing = completions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            context.delete(existing)
        } else {
            let completion = HabitCompletion(date: date)
            completion.habit = self
            completions.append(completion)
            context.insert(completion)
        }
        try? context.save()
    }

    // Current streak: consecutive days completed ending today
    func currentStreak() -> Int {
        var streak = 0
        var date = Date.now.startOfDay
        while true {
            if isCompleted(on: date) {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }
        return streak
    }

    // Longest streak ever
    func longestStreak() -> Int {
        let sortedDates = completions.map { $0.date.startOfDay }.sorted()
        guard !sortedDates.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<sortedDates.count {
            let diff = Calendar.current.dateComponents([.day], from: sortedDates[i - 1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
    }
}
