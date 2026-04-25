import SwiftData
import Foundation

@Model
final class HabitCompletion {
    var date: Date = Date()
    /// Per-day free-text note. Optional with a `nil` default so SwiftData
    /// performs a lightweight inferred migration on existing stores —
    /// rows written before this field existed simply have `note == nil`.
    /// Daniel relies on this for journaling daily context (e.g. "did 50
    /// pushups during lunch") on r1 builds; this restores parity on main.
    var note: String? = nil
    @Relationship(inverse: \Habit.completions) var habit: Habit?

    init(date: Date = .now, note: String? = nil) {
        self.date = date.startOfDay
        self.note = note
    }
}
