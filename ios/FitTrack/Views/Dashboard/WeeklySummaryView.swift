import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Query private var allWorkouts: [Workout]

    private var calendar: Calendar { Calendar.current }

    private var thisWeekStart: Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var lastWeekStart: Date {
        calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? Date()
    }

    private var thisWeekWorkouts: [Workout] {
        allWorkouts.filter { $0.date >= thisWeekStart }
    }

    private var lastWeekWorkouts: [Workout] {
        allWorkouts.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
    }

    private var thisWeekVolume: Double {
        totalVolume(for: thisWeekWorkouts)
    }

    private var lastWeekVolume: Double {
        totalVolume(for: lastWeekWorkouts)
    }

    private var thisWeekDuration: Int {
        thisWeekWorkouts.compactMap(\.durationMinutes).reduce(0, +)
    }

    private var lastWeekDuration: Int {
        lastWeekWorkouts.compactMap(\.durationMinutes).reduce(0, +)
    }

    private var streak: Int {
        let sorted = allWorkouts.sorted { $0.date > $1.date }
        guard !sorted.isEmpty else { return 0 }

        var count = 0
        var checkDate = calendar.startOfDay(for: Date())

        for workout in sorted {
            let workoutDay = calendar.startOfDay(for: workout.date)
            if workoutDay == checkDate {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if workoutDay < checkDate {
                // Check if we just need to skip ahead (no workout on checkDate)
                if count == 0 {
                    // First workout isn't today, check if it was yesterday
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
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    icon: "flame.fill",
                    label: "Workouts",
                    value: "\(thisWeekWorkouts.count)",
                    comparison: thisWeekWorkouts.count - lastWeekWorkouts.count,
                    color: .orange
                )
                summaryCard(
                    icon: "clock.fill",
                    label: "Duration",
                    value: "\(thisWeekDuration) min",
                    comparison: thisWeekDuration - lastWeekDuration,
                    color: .blue
                )
                summaryCard(
                    icon: "scalemass.fill",
                    label: "Volume",
                    value: formatVolume(thisWeekVolume),
                    comparison: Int(thisWeekVolume - lastWeekVolume),
                    color: .emerald
                )
                summaryCard(
                    icon: "bolt.fill",
                    label: "Streak",
                    value: "\(streak) days",
                    comparison: nil,
                    color: .yellow
                )
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
                .foregroundStyle(.white)

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

    private func totalVolume(for workouts: [Workout]) -> Double {
        workouts.flatMap(\.sets).compactMap { set -> Double? in
            guard let w = set.weight, let r = set.reps else { return nil }
            return w * Double(r)
        }.reduce(0, +)
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 {
            return "\(Int(v / 1000))k lbs"
        }
        return "\(Int(v)) lbs"
    }
}
