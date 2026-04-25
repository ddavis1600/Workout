import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    // Bounded @Query fetches (AUDIT H3).
    //
    // Previous shape was four unbounded `@Query` fetches, then in-memory
    // filter to "this week." On an account with months of history that
    // dragged every row through SwiftUI diffing just to render a four-
    // card summary, and with CloudKit sync turned on it triggered a
    // full record pull per refresh.
    //
    // Strategy: scope each query to the minimum window any computed
    // property needs. Everything except `streak` only looks at the
    // trailing 14 days (this-week + last-week comparisons); streak is
    // bounded at 90 days, plenty for what's UX-relevant.
    //
    // The `#Predicate` DSL blocks global functions like
    // `Date(timeIntervalSinceNow:)` so the cutoffs are computed in
    // `init()` and captured as locals. SwiftUI re-instantiates the
    // view on every refresh, so the window slides with wall clock.
    @Query private var recentWorkouts: [Workout]
    @Query private var recentDiaryEntries: [DiaryEntry]
    @Query private var recentWeightEntries: [WeightEntry]

    // Habits themselves are few (< ~30). Keep unbounded — the weekly
    // completion-rate math walks the relationship, so we can't bound
    // the habit list by completion date here anyway.
    @Query private var allHabits: [Habit]

    init() {
        let now = Date()
        let workoutCutoff  = now.addingTimeInterval(-90 * 24 * 3600)
        let twoWeekCutoff  = now.addingTimeInterval(-14 * 24 * 3600)

        _recentWorkouts = Query(
            filter: #Predicate<Workout> { $0.date >= workoutCutoff },
            sort: \Workout.date,
            order: .reverse
        )
        _recentDiaryEntries = Query(
            filter: #Predicate<DiaryEntry> { $0.date >= twoWeekCutoff }
        )
        _recentWeightEntries = Query(
            filter: #Predicate<WeightEntry> { $0.date >= twoWeekCutoff }
        )
    }

    private var calendar: Calendar { Calendar.current }

    private var thisWeekStart: Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var lastWeekStart: Date {
        calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? Date()
    }

    private var thisWeekWorkouts: [Workout] {
        recentWorkouts.filter { $0.date >= thisWeekStart }
    }

    private var lastWeekWorkouts: [Workout] {
        recentWorkouts.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
    }

    private var thisWeekDuration: Int {
        thisWeekWorkouts.compactMap(\.durationMinutes).reduce(0, +)
    }

    private var lastWeekDuration: Int {
        lastWeekWorkouts.compactMap(\.durationMinutes).reduce(0, +)
    }

    // MARK: - Calories

    private var thisWeekDiaryEntries: [DiaryEntry] {
        recentDiaryEntries.filter { $0.date >= thisWeekStart }
    }

    private var avgDailyCalories: Int {
        let days = max(1, calendar.dateComponents([.day], from: thisWeekStart, to: Date()).day ?? 1)
        let total = thisWeekDiaryEntries.reduce(0.0) { $0 + $1.totalCalories }
        return Int(total / Double(days))
    }

    // MARK: - Weight change

    private var thisWeekWeightEntries: [WeightEntry] {
        recentWeightEntries.filter { $0.date >= thisWeekStart }.sorted { $0.date < $1.date }
    }

    private var weightChange: Double? {
        guard thisWeekWeightEntries.count >= 2 else { return nil }
        let first = thisWeekWeightEntries.first!.weight
        let last = thisWeekWeightEntries.last!.weight
        return last - first
    }

    // MARK: - Habits

    private var habitCompletionRate: Int {
        guard !allHabits.isEmpty else { return 0 }
        let days = max(1, calendar.dateComponents([.day], from: thisWeekStart, to: Date()).day ?? 1)
        let totalPossible = allHabits.count * days
        let completed = allHabits.reduce(0) { count, habit in
            let weekCompletions = (habit.completions ?? []).filter { $0.date >= thisWeekStart }.count
            return count + weekCompletions
        }
        return Int(round(Double(completed) / Double(totalPossible) * 100))
    }

    // MARK: - Streak

    private var streak: Int {
        // `recentWorkouts` is already ordered .reverse from the query,
        // so the previous explicit re-sort is redundant — saves an
        // O(n log n) on every recomputation.
        guard !recentWorkouts.isEmpty else { return 0 }

        var count = 0
        var checkDate = calendar.startOfDay(for: Date())

        for workout in recentWorkouts {
            let workoutDay = calendar.startOfDay(for: workout.date)
            if workoutDay == checkDate {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if workoutDay < checkDate {
                if count == 0 {
                    let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
                    if workoutDay == yesterday {
                        count = 1
                        checkDate = calendar.date(byAdding: .day, value: -1, to: yesterday) ?? yesterday
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(Color.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    icon: "dumbbell.fill",
                    label: "Workouts",
                    value: "\(thisWeekWorkouts.count)",
                    comparison: thisWeekWorkouts.count - lastWeekWorkouts.count,
                    color: .orange
                )
                summaryCard(
                    icon: "flame.fill",
                    label: "Avg Calories",
                    value: "\(avgDailyCalories) kcal",
                    comparison: nil,
                    color: .red
                )
                if let change = weightChange {
                    summaryCard(
                        icon: "scalemass.fill",
                        label: "Weight Change",
                        value: String(format: "%+.1f kg", change),
                        comparison: nil,
                        color: change <= 0 ? .emerald : .orange
                    )
                } else {
                    summaryCard(
                        icon: "clock.fill",
                        label: "Duration",
                        value: "\(thisWeekDuration) min",
                        comparison: thisWeekDuration - lastWeekDuration,
                        color: .blue
                    )
                }
                if !allHabits.isEmpty {
                    summaryCard(
                        icon: "checkmark.circle.fill",
                        label: "Habits Done",
                        value: "\(habitCompletionRate)%",
                        comparison: nil,
                        color: .emerald
                    )
                } else {
                    summaryCard(
                        icon: "bolt.fill",
                        label: "Streak",
                        value: "\(streak) days",
                        comparison: nil,
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    private func summaryCard(icon: String, label: String, value: String, comparison: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.ink)

            if let diff = comparison {
                HStack(spacing: 2) {
                    Image(systemName: diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "minus")
                        .font(.system(size: 9))
                    Text("vs last week")
                        .font(.system(size: 9))
                }
                .foregroundStyle(diff > 0 ? .green : diff < 0 ? .red : Color.slateText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.slateBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
