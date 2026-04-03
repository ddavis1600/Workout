import SwiftData
import Foundation

@Model
final class Habit {
    var name: String = ""
    var icon: String = "checkmark.circle"
    var color: String = "emerald"
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]

    init(name: String, icon: String = "checkmark.circle", color: String = "emerald") {
        self.name = name
        self.icon = icon
        self.color = color
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

    // Streak: count consecutive days completed ending at today
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
}
