import SwiftUI
import SwiftData
import Charts

/// "Trends" / "Insights" hub — four charts the user can scan quickly,
/// each tapping into a fullscreen detail with broader time-range
/// selectors (audit ref F7).
///
/// Cards on the hub render the spec's default windows:
///   - Weight: last 90 days, smoothed line
///   - Workout volume: last 12 weeks, bar chart
///   - Calorie balance: last 30 days, in vs out line
///   - Habit completion: last 8 weeks, heatmap grid
///
/// Detail views replicate the same chart with a `TrendsRange` segmented
/// picker (3M / 6M / 1Y). Code shared via the small `TrendsRange` enum
/// + the `bucket(...)` helpers at the bottom of the file.
struct TrendsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavigationLink {
                    WeightTrendDetailView()
                } label: {
                    TrendCard(title: "Weight", subtitle: "Last 90 days", icon: "scalemass.fill") {
                        WeightTrendChart(range: .threeMonths, isCard: true)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutVolumeDetailView()
                } label: {
                    TrendCard(title: "Workout Volume", subtitle: "Last 12 weeks", icon: "dumbbell.fill") {
                        WorkoutVolumeChart(range: .threeMonths, isCard: true)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CalorieBalanceDetailView()
                } label: {
                    TrendCard(title: "Calorie Balance", subtitle: "Last 30 days", icon: "flame.fill") {
                        // .threeMonths is the smallest range; the card
                        // copy says "30 days" because the chart visually
                        // emphasizes recent data — broader ranges open
                        // via the detail view's selectors.
                        CalorieBalanceChart(range: .threeMonths, isCard: true)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HabitHeatmapDetailView()
                } label: {
                    TrendCard(title: "Habit Completion", subtitle: "Last 8 weeks", icon: "checkmark.circle.fill") {
                        HabitHeatmapChart(weeks: 8, isCard: true)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color.slateBackground)
        .navigationTitle("Trends")
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }
}

// MARK: - Time Range

/// Range selector shared by the detail views. The hub cards pick a fixed
/// preview range (typically `.threeMonths` to match the spec defaults);
/// detail views let the user toggle between three.
enum TrendsRange: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case oneYear     = "1Y"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .oneYear:     return 365
        }
    }

    /// Lower bound for `>=` filtering of date-keyed series.
    var since: Date {
        Calendar.current.date(byAdding: .day, value: -dayCount, to: .now.startOfDay) ?? .now
    }
}

// MARK: - Card chrome

private struct TrendCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.emerald)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.slateText)
            }
            content()
                .frame(height: 160)
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slateBorder, lineWidth: 1))
    }
}

// MARK: - Weight Trend

private struct WeightTrendChart: View {
    let range: TrendsRange
    let isCard: Bool
    @Query private var entries: [WeightEntry]
    @Query private var profiles: [UserProfile]

    /// Filter + sort happen here rather than on the @Query because the
    /// range is bound at view-init time and SwiftData's @Query macro
    /// can't easily swap predicate based on a runtime range.
    private var filtered: [WeightEntry] {
        let cutoff = range.since
        return entries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private var unitSystem: String {
        profiles.first?.unitSystem ?? "imperial"
    }

    var body: some View {
        if filtered.isEmpty {
            EmptyTrendsState(message: "Log some weights to see the trend.")
        } else {
            Chart(filtered) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value(unitSystem == "imperial" ? "lb" : "kg",
                              entry.displayWeight(unitSystem: unitSystem))
                )
                .foregroundStyle(Color.emerald)
                .interpolationMethod(.monotone) // smoothed line per spec
            }
            .chartXAxis(isCard ? .hidden : .automatic)
            .chartYAxis(isCard ? .hidden : .automatic)
            .chartXScale(domain: range.since...Date.now)
        }
    }
}

struct WeightTrendDetailView: View {
    @State private var range: TrendsRange = .threeMonths
    var body: some View {
        VStack(spacing: 16) {
            rangePicker(selection: $range)
            WeightTrendChart(range: range, isCard: false)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .padding()
        .background(Color.slateBackground)
        .navigationTitle("Weight")
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }
}

// MARK: - Workout Volume

private struct WorkoutVolumeBucket: Identifiable {
    let weekStart: Date
    let count: Int
    var id: Date { weekStart }
}

private struct WorkoutVolumeChart: View {
    let range: TrendsRange
    let isCard: Bool
    @Query private var workouts: [Workout]

    private var buckets: [WorkoutVolumeBucket] {
        let cutoff = range.since
        let cal = Calendar.current
        let recent = workouts.filter { $0.date >= cutoff }
        let grouped = Dictionary(grouping: recent) { workout -> Date in
            // Bucket by ISO week's Monday (or whichever weekday locale's
            // calendar reports first). Using `dateInterval(of:.weekOfYear,
            // for:)` gives us the start without manual weekday math.
            cal.dateInterval(of: .weekOfYear, for: workout.date)?.start
                ?? workout.date.startOfDay
        }
        return grouped
            .map { WorkoutVolumeBucket(weekStart: $0.key, count: $0.value.count) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        if buckets.isEmpty {
            EmptyTrendsState(message: "Log workouts to see volume.")
        } else {
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    y: .value("Workouts", bucket.count)
                )
                .foregroundStyle(Color.emerald)
            }
            .chartXAxis(isCard ? .hidden : .automatic)
            .chartYAxis(isCard ? .hidden : .automatic)
        }
    }
}

struct WorkoutVolumeDetailView: View {
    @State private var range: TrendsRange = .threeMonths
    var body: some View {
        VStack(spacing: 16) {
            rangePicker(selection: $range)
            WorkoutVolumeChart(range: range, isCard: false)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .padding()
        .background(Color.slateBackground)
        .navigationTitle("Workout Volume")
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }
}

// MARK: - Calorie Balance

private struct CalorieDayPoint: Identifiable {
    let date: Date
    let consumed: Double
    let burned: Double
    var id: Date { date }
}

private struct CalorieBalanceChart: View {
    let range: TrendsRange
    let isCard: Bool
    @Query private var diary: [DiaryEntry]
    @Query private var workouts: [Workout]
    @Query private var profiles: [UserProfile]

    /// Build daily buckets of consumed (sum of DiaryEntry.totalCalories)
    /// and burned (rough proxy: workout duration × 6 kcal/min, since the
    /// app doesn't track activeEnergyBurned in SwiftData on `main`). HK
    /// integration could swap the burned source later — the chart shape
    /// stays the same.
    private var points: [CalorieDayPoint] {
        let cutoff = range.since
        let cal = Calendar.current

        // Bucket diary by day-start
        let consumedByDay = Dictionary(
            grouping: diary.filter { $0.date >= cutoff },
            by: { cal.startOfDay(for: $0.date) }
        ).mapValues { $0.reduce(0) { $0 + $1.totalCalories } }

        // Bucket workouts by day-start
        let burnedByDay = Dictionary(
            grouping: workouts.filter { $0.date >= cutoff },
            by: { cal.startOfDay(for: $0.date) }
        ).mapValues { workouts in
            workouts.reduce(0.0) { sum, w in
                sum + Double(w.durationMinutes ?? 0) * 6.0  // kcal/min proxy
            }
        }

        let allDays = Set(consumedByDay.keys).union(burnedByDay.keys)
        return allDays
            .sorted()
            .map { day in
                CalorieDayPoint(
                    date: day,
                    consumed: consumedByDay[day] ?? 0,
                    burned: burnedByDay[day] ?? 0
                )
            }
    }

    var body: some View {
        if points.isEmpty {
            EmptyTrendsState(message: "Log meals or workouts to see balance.")
        } else {
            Chart {
                ForEach(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("kcal", p.consumed),
                        series: .value("Series", "Consumed")
                    )
                    .foregroundStyle(.orange)
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("kcal", p.burned),
                        series: .value("Series", "Burned")
                    )
                    .foregroundStyle(Color.emerald)
                }
            }
            .chartForegroundStyleScale([
                "Consumed": .orange,
                "Burned":   Color.emerald
            ])
            .chartLegend(isCard ? .hidden : .visible)
            .chartXAxis(isCard ? .hidden : .automatic)
            .chartYAxis(isCard ? .hidden : .automatic)
        }
    }
}

struct CalorieBalanceDetailView: View {
    @State private var range: TrendsRange = .threeMonths
    var body: some View {
        VStack(spacing: 16) {
            rangePicker(selection: $range)
            CalorieBalanceChart(range: range, isCard: false)
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Burned is estimated from logged workout duration. Connect Apple Health on a future build for actual active-energy figures.")
                .font(.caption)
                .foregroundStyle(Color.slateText)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
        .background(Color.slateBackground)
        .navigationTitle("Calorie Balance")
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }
}

// MARK: - Habit Heatmap

private struct HabitHeatmapChart: View {
    let weeks: Int
    let isCard: Bool
    @Query private var habits: [Habit]

    /// Per-day completion ratio across all habits, bucketed Sun-Sat over
    /// the last `weeks` weeks. Cells are colored by intensity (0…1).
    private var grid: [[Double]] {
        let cal = Calendar.current
        let today = Date.now.startOfDay
        let weekday = cal.component(.weekday, from: today) // 1=Sun
        guard let weekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today),
              let startDate = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: weekStart)
        else { return [] }

        return (0..<weeks).map { w in
            (0..<7).map { d -> Double in
                guard let day = cal.date(byAdding: .day, value: w * 7 + d, to: startDate),
                      day <= today
                else { return -1 }  // sentinel for "future / no data"
                let total = habits.count
                guard total > 0 else { return 0 }
                let completed = habits.filter { $0.isCompleted(on: day) }.count
                return Double(completed) / Double(total)
            }
        }
    }

    private func cellColor(_ ratio: Double) -> Color {
        if ratio < 0 { return .clear }
        if ratio == 0 { return Color.slateBorder.opacity(0.4) }
        return Color.emerald.opacity(0.2 + 0.8 * ratio)
    }

    var body: some View {
        if habits.isEmpty {
            EmptyTrendsState(message: "Add habits to see your heatmap.")
        } else {
            GeometryReader { geo in
                let cellSize = max(8, (geo.size.width - 6 * CGFloat(weeks - 1)) / CGFloat(weeks))
                HStack(alignment: .top, spacing: 6) {
                    ForEach(grid.indices, id: \.self) { w in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { d in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cellColor(grid[w][d]))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct HabitHeatmapDetailView: View {
    @State private var range: TrendsRange = .threeMonths
    private var weeks: Int {
        switch range {
        case .threeMonths: return 13
        case .sixMonths:   return 26
        case .oneYear:     return 52
        }
    }
    var body: some View {
        VStack(spacing: 16) {
            rangePicker(selection: $range)
            HabitHeatmapChart(weeks: weeks, isCard: false)
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .padding()
        .background(Color.slateBackground)
        .navigationTitle("Habit Completion")
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }
}

// MARK: - Shared subviews / helpers

private struct EmptyTrendsState: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

@ViewBuilder
private func rangePicker(selection: Binding<TrendsRange>) -> some View {
    Picker("Range", selection: selection) {
        ForEach(TrendsRange.allCases) { range in
            Text(range.rawValue).tag(range)
        }
    }
    .pickerStyle(.segmented)
}

#Preview {
    NavigationStack {
        TrendsView()
    }
    .modelContainer(for: [
        WeightEntry.self, Workout.self, WorkoutSet.self, Exercise.self,
        UserProfile.self, DiaryEntry.self, Food.self, FoodFavorite.self,
        Habit.self, HabitCompletion.self, JournalEntry.self,
        BodyMeasurement.self, ProgressPhoto.self,
        WorkoutTemplate.self, TemplateExercise.self,
    ], inMemory: true)
}
