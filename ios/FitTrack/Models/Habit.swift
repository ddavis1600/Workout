import SwiftData
import Foundation

@Model
final class Habit {
    var name: String = ""
    var icon: String = "checkmark.circle"
    var color: String = "emerald"
    var createdAt: Date = Date()
    var healthKitTrigger: String?
    var healthKitThreshold: Double = 0
    // Scheduling
    var scheduledDays: [Int] = []       // 0=Sun…6=Sat; empty = every day
    var reminderTime: Date? = nil
    var weeklyTarget: Int = 7
    // Organization
    var category: String = "Custom"
    var sortOrder: Int = 0
    // Gamification
    var earnedBadges: [Int] = []        // milestone days: 7, 30, 100
    var freezeAppliedDates: [Date] = [] // dates where streak freeze was applied

    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]

    init(name: String, icon: String = "checkmark.circle", color: String = "emerald",
         healthKitTrigger: String? = nil, healthKitThreshold: Double = 0,
         scheduledDays: [Int] = [], reminderTime: Date? = nil,
         weeklyTarget: Int = 7, category: String = "Custom", sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.color = color
        self.healthKitTrigger = healthKitTrigger
        self.healthKitThreshold = healthKitThreshold
        self.createdAt = .now
        self.completions = []
        self.scheduledDays = scheduledDays
        self.reminderTime = reminderTime
        self.weeklyTarget = weeklyTarget
        self.category = category
        self.sortOrder = sortOrder
        self.earnedBadges = []
        self.freezeAppliedDates = []
    }

    // MARK: - Completion

    func isCompleted(on date: Date) -> Bool {
        let inCompletions = completions.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if inCompletions { return true }
        return freezeAppliedDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
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

    // MARK: - Scheduling

    func isScheduledOn(_ date: Date) -> Bool {
        guard !scheduledDays.isEmpty else { return true }
        let weekday = Calendar.current.component(.weekday, from: date) - 1 // 0=Sun
        return scheduledDays.contains(weekday)
    }

    // MARK: - Streaks

    func currentStreak() -> Int {
        var streak = 0
        var date = Date.now.startOfDay
        while isCompleted(on: date) {
            streak += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return streak
    }

    func longestStreak() -> Int {
        var allDates = Set(completions.map { $0.date.startOfDay })
        for d in freezeAppliedDates { allDates.insert(d.startOfDay) }
        let sorted = allDates.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sorted.count {
            let diff = Calendar.current.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) }
            else if diff > 1 { current = 1 }
        }
        return longest
    }

    // MARK: - Weekly Progress

    func weeklyProgress(for referenceDate: Date = .now) -> (completed: Int, target: Int) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: referenceDate) // 1=Sun
        guard let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: referenceDate.startOfDay) else {
            return (0, weeklyTarget)
        }
        var completed = 0
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: startOfWeek) else { continue }
            if day > referenceDate.startOfDay { break }
            if isCompleted(on: day) { completed += 1 }
        }
        return (completed, weeklyTarget)
    }

    func isOnTrack(for referenceDate: Date = .now) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: referenceDate) // 1=Sun
        let daysElapsed = max(1, weekday)
        let (completed, target) = weeklyProgress(for: referenceDate)
        let required = Int(ceil(Double(target) * Double(daysElapsed) / 7.0))
        return completed >= required
    }

    func completions(from startDate: Date, days: Int) -> Int {
        var count = 0
        for i in 0..<days {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: startDate),
               isCompleted(on: day) { count += 1 }
        }
        return count
    }

    // MARK: - Streak Freeze

    func canApplyFreeze(forWeekOf date: Date) -> Bool {
        guard !isCompleted(on: date) else { return false }
        let cal = Calendar.current
        let target = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return !freezeAppliedDates.contains { d in
            let w = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            return w.yearForWeekOfYear == target.yearForWeekOfYear && w.weekOfYear == target.weekOfYear
        }
    }

    func applyFreeze(for date: Date, context: ModelContext) {
        guard canApplyFreeze(forWeekOf: date) else { return }
        freezeAppliedDates.append(date.startOfDay)
        try? context.save()
    }

    // MARK: - Stats

    func allTimeCompletionRate() -> Double {
        let days = max(1, Calendar.current.dateComponents([.day], from: createdAt.startOfDay, to: Date.now.startOfDay).day ?? 1)
        return Double(completions.count + freezeAppliedDates.count) / Double(days)
    }

    func newlyEarnedMilestones() -> [Int] {
        let streak = currentStreak()
        return [7, 30, 100].filter { streak >= $0 && !earnedBadges.contains($0) }
    }
}
