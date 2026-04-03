import SwiftData
import Foundation

@Model
final class HabitCompletion {
    var date: Date = Date()
    @Relationship(inverse: \Habit.completions) var habit: Habit?

    init(date: Date = .now) {
        self.date = date.startOfDay
    }
}
