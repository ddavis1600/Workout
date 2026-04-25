import Foundation
import SwiftData

/// Seeds illustrative starter data when the user opts in on the
/// final onboarding step (audit ref F5 — sample-data toggle).
///
/// What gets created:
///   - 3 sample workouts spread across the last 7 days, each with a
///     handful of WorkoutSets attached to existing seeded Exercises.
///   - 3 sample habits (Drink Water, Walk 10k Steps, Read 20 min)
///     each with a 7-day completion streak so the streak widget
///     and habit heatmap have something to render.
///
/// Deliberate non-actions:
///   - We do NOT seed `DiaryEntry` rows. The diary's empty state is
///     useful — it teaches the search affordance — and meals are too
///     personal to fake.
///   - We do NOT seed `WeightEntry` rows. The "log your first weight"
///     empty state is the right teaching moment for that screen.
///
/// All inserted rows are normal SwiftData @Model instances — the user
/// can edit or delete them like any real data, and CloudKit will sync
/// them across devices.
enum OnboardingSampleData {
    /// Idempotency: if any Workout already exists, skip seeding.
    /// This protects against a user toggling the option, completing
    /// onboarding, then somehow re-entering the flow (e.g. after a
    /// data wipe followed by CloudKit re-sync).
    static func seed(context: ModelContext) {
        let workoutCount = (try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0
        guard workoutCount == 0 else { return }

        seedWorkouts(context: context)
        seedHabitsWithStreak(context: context)
        try? context.save()
    }

    // MARK: - Workouts

    private static func seedWorkouts(context: ModelContext) {
        // Best-effort exercise lookup by name. Exercises are seeded by
        // `DataController.seedDataIfNeeded`, which runs at app init
        // before onboarding completes, so by the time the user toggles
        // sample data the catalog is populated.
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func find(_ name: String) -> Exercise? {
            allExercises.first { $0.name == name }
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Workout 1 — 6 days ago: full upper-body push.
        if let date = cal.date(byAdding: .day, value: -6, to: today) {
            let w = Workout(
                name: "Push Day",
                date: date,
                notes: "Sample data — feel free to delete.",
                durationMinutes: 52
            )
            context.insert(w)
            attachSets(to: w, in: context, plan: [
                ("Bench Press",        [(reps: 8, weight: 135), (reps: 6, weight: 145), (reps: 5, weight: 155)]),
                ("Overhead Press",     [(reps: 8, weight: 75),  (reps: 6, weight: 85)]),
                ("Tricep Pushdown",    [(reps: 12, weight: 50), (reps: 10, weight: 55)]),
            ], lookup: find)
        }

        // Workout 2 — 3 days ago: pull / back-focused.
        if let date = cal.date(byAdding: .day, value: -3, to: today) {
            let w = Workout(
                name: "Pull Day",
                date: date,
                notes: "Sample data — feel free to delete.",
                durationMinutes: 48
            )
            context.insert(w)
            attachSets(to: w, in: context, plan: [
                ("Deadlift",      [(reps: 5, weight: 185), (reps: 5, weight: 205), (reps: 3, weight: 225)]),
                ("Pull-ups",      [(reps: 8, weight: 0),   (reps: 6, weight: 0)]),
                ("Bicep Curl",    [(reps: 12, weight: 25), (reps: 10, weight: 30)]),
            ], lookup: find)
        }

        // Workout 3 — yesterday: legs.
        if let date = cal.date(byAdding: .day, value: -1, to: today) {
            let w = Workout(
                name: "Leg Day",
                date: date,
                notes: "Sample data — feel free to delete.",
                durationMinutes: 56
            )
            context.insert(w)
            attachSets(to: w, in: context, plan: [
                ("Squat",         [(reps: 8, weight: 155), (reps: 6, weight: 175), (reps: 5, weight: 195)]),
                ("Leg Press",     [(reps: 10, weight: 200), (reps: 10, weight: 220)]),
                ("Calf Raises",   [(reps: 15, weight: 90),  (reps: 12, weight: 100)]),
            ], lookup: find)
        }
    }

    /// Attach a list of (exerciseName, [(reps, weight)]) tuples to a
    /// freshly-inserted Workout. Skips quietly if an exercise can't
    /// be found in the seeded catalog — sample data shouldn't crash
    /// onboarding if a future revision renames an exercise.
    private static func attachSets(
        to workout: Workout,
        in context: ModelContext,
        plan: [(name: String, sets: [(reps: Int, weight: Double)])],
        lookup: (String) -> Exercise?
    ) {
        for group in plan {
            guard let exercise = lookup(group.name) else { continue }
            for (idx, setEntry) in group.sets.enumerated() {
                let set = WorkoutSet(
                    exercise: exercise,
                    setNumber: idx + 1,
                    reps: setEntry.reps,
                    weight: setEntry.weight,
                    rpe: nil,
                    notes: ""
                )
                if workout.sets != nil {
                    workout.sets!.append(set)
                } else {
                    workout.sets = [set]
                }
                context.insert(set)
            }
        }
    }

    // MARK: - Habits with streak

    private static func seedHabitsWithStreak(context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let templates: [(name: String, icon: String, color: String, category: String)] = [
            ("Drink Water",      "drop.fill",            "blue",    "Nutrition"),
            ("Walk 10k Steps",   "figure.walk",          "emerald", "Fitness"),
            ("Read 20 min",      "book.fill",            "purple",  "Morning"),
        ]

        for (idx, template) in templates.enumerated() {
            let habit = Habit(
                name: template.name,
                icon: template.icon,
                color: template.color,
                weeklyTarget: 7,
                category: template.category,
                sortOrder: idx
            )
            context.insert(habit)

            // 7-day streak ending today — gives the streak widget +
            // habit heatmap a non-empty starting point.
            for daysAgo in 0..<7 {
                guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
                let completion = HabitCompletion(date: date)
                completion.habit = habit
                if habit.completions != nil {
                    habit.completions!.append(completion)
                } else {
                    habit.completions = [completion]
                }
                context.insert(completion)
            }
        }
    }
}
