import Foundation
import SwiftData
import WidgetKit

/// Snapshot of the data the Home Screen widgets render.
///
/// Written by the main app to the shared App Group `UserDefaults` whenever
/// any of the underlying values change (see `refresh(from:)`), then read by
/// the widget extension's timeline provider. Keeping the payload small and
/// `Codable` means it round-trips cheaply through `JSONEncoder`/`Decoder`.
///
/// Field coverage maps 1:1 to the three widgets (F1 in the audit):
///   - **Today's Stats** (small + medium): `caloriesConsumed`,
///     `caloriesBurned`, `steps`.
///   - **Streak** (small): `currentStreak`, `streakHabitName`.
///   - **Today's Workout** (medium): `todayWorkoutName`,
///     `todayWorkoutDurationMinutes` (nil if no workout logged today).
struct WidgetSnapshot: Codable, Equatable {
    var caloriesConsumed: Int = 0
    var caloriesBurned: Int = 0
    var steps: Int = 0
    var calorieTarget: Int = 2000

    var currentStreak: Int = 0
    var streakHabitName: String = ""

    var todayWorkoutName: String? = nil
    var todayWorkoutDurationMinutes: Int? = nil

    var lastUpdated: Date = .now

    /// JSON key inside the App Group `UserDefaults` suite.
    static let userDefaultsKey = "widget.snapshot.v1"

    /// Empty/loading state used by the widget when no snapshot has ever
    /// been written (e.g. first install before the user opens the app).
    static let placeholder = WidgetSnapshot()
}

// MARK: - Read

extension WidgetSnapshot {
    /// Read the latest snapshot. Returns `placeholder` on first read /
    /// decode failure so widget views always have something to render.
    static func load() -> WidgetSnapshot {
        guard let data = AppGroup.userDefaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return decoded
    }
}

// MARK: - Write (main app only)

#if !WIDGET_EXTENSION
extension WidgetSnapshot {
    /// Build a fresh snapshot from the current SwiftData state and write
    /// it to the shared App Group, then ask `WidgetCenter` to reload
    /// every widget timeline.
    ///
    /// Call this on save paths that touch any field in the snapshot:
    ///   - new `DiaryEntry` (calories consumed)
    ///   - new `Workout` (calories burned + today's workout)
    ///   - new `HabitCompletion` (streak)
    ///
    /// `try? context.save()` is the caller's responsibility — this method
    /// only reads; if the save hasn't landed yet the snapshot will lag by
    /// one tick. In practice every call site saves first, then refreshes.
    ///
    /// Not annotated `@MainActor`: the body only does in-memory fetches
    /// + `UserDefaults` + `WidgetCenter` calls, none of which require
    /// main-actor isolation. Callers from view-model methods (like
    /// `DiaryViewModel.addEntry`) can therefore invoke synchronously.
    static func refresh(from context: ModelContext) {
        var snapshot = WidgetSnapshot()
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: .now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        // Calorie target — first profile (single-user app)
        if let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first,
           profile.calorieTarget > 0 {
            snapshot.calorieTarget = Int(profile.calorieTarget)
        }

        // Calories consumed — sum DiaryEntry.totalCalories for today
        let diaryDescriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
        )
        if let entries = try? context.fetch(diaryDescriptor) {
            snapshot.caloriesConsumed = Int(entries.reduce(0) { $0 + $1.totalCalories })
        }

        // Today's workout — most recent for today
        let workoutDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date >= dayStart && workout.date < dayEnd
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let todayWorkouts = try? context.fetch(workoutDescriptor),
           let mostRecent = todayWorkouts.first {
            snapshot.todayWorkoutName = mostRecent.name.isEmpty ? "Workout" : mostRecent.name
            snapshot.todayWorkoutDurationMinutes = mostRecent.durationMinutes
        }

        // Calories burned — rough estimate from workouts.duration × MET
        // assumption. We don't yet read activeEnergyBurned from HK in a
        // shared way; leaving a TODO marker by mirroring the diary value
        // back out as 0 keeps the field present for future wiring.
        snapshot.caloriesBurned = 0

        // Steps — populated by the main app from HK on the next foreground
        // refresh; widget reads this lazily. Default 0 if HK unavailable.
        snapshot.steps = 0

        // Streak — pick the habit with the longest current streak, since
        // multiple habits are common and "streak" without context is
        // ambiguous. Empty habits → 0.
        if let habits = try? context.fetch(FetchDescriptor<Habit>()),
           let best = habits.max(by: { $0.currentStreak() < $1.currentStreak() }) {
            snapshot.currentStreak = best.currentStreak()
            snapshot.streakHabitName = best.name
        }

        snapshot.lastUpdated = .now
        snapshot.persist()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Update only the HK-derived fields (steps + activeEnergyBurned)
    /// without re-reading SwiftData. Called from a foreground HK fetch
    /// when the main app has fresh values but the rest of the snapshot
    /// would be unchanged.
    static func updateHealthKitFields(steps: Int, caloriesBurned: Int) {
        var snapshot = load()
        snapshot.steps = steps
        snapshot.caloriesBurned = caloriesBurned
        snapshot.lastUpdated = .now
        snapshot.persist()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
#endif
