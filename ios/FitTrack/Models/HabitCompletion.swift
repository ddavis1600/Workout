import SwiftData
import Foundation

@Model
final class HabitCompletion {
    var date: Date
    var habit: Habit?

    init(date: Date = .now) {
        self.date = date.startOfDay
    }
}
