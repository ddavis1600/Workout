import SwiftData
import Foundation

@Model
final class HabitCompletion {
    var date: Date = Date()
    var note: String? = nil
    @Relationship(inverse: \Habit.completions) var habit: Habit?

    init(date: Date = .now, note: String? = nil) {
        self.date = date.startOfDay
        self.note = note
    }
}
