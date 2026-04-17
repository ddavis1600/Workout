import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let habit: Habit

    private var calendar: Calendar { Calendar.current }

    // 12 weeks × 7 days grid (columns=weeks left→right, rows=Sun→Sat)
    private var heatmapWeeks: [[Date?]] {
        let today = Date.now.startOfDay
        let weekday = calendar.component(.weekday, from: today) // 1=Sun
        guard let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let startDate = calendar.date(byAdding: .weekOfYear, value: -11, to: weekStart) else {
            return []
        }
        return (0..<12).map { w in
            guard let ws = calendar.date(byAdding: .weekOfYear, value: w, to: startDate) else { return [] }
            return (0..<7).map { d in
                guard let day = calendar.date(byAdding: .day, value: d, to: ws) else { return nil }
                return day <= today ? day : nil
            }
        }
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    heatmapSection
                    if !habit.earnedBadges.isEmpty { badgesSection }
                }
                .padding()
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard("\(habit.currentStreak())", "Streak", "🔥")
            statCard("\(habit.longestStreak())", "Best", "🏆")
            statCard("\(Int(habit.allTimeCompletionRate() * 100))%", "Rate", "📊")
        }
    }

    private func statCard(_ value: String, _ label: String, _ emoji: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.title2)
            Text(value).font(.title2.weight(.bold)).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.slateCard)
        .cornerRadius(12)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 12 Weeks")
                .font(.headline).foregroundColor(.white)

            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 4) {
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9))
                            .foregroundColor(.slateText)
                            .frame(width: 12, height: 14)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(heatmapWeeks.indices, id: \.self) { w in
                            VStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { d in
                                    heatCell(heatmapWeeks[w][d])
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func heatCell(_ date: Date?) -> some View {
        let completed = date.map { habit.isCompleted(on: $0) } ?? false
        let frozen = date.map { d in
            habit.freezeAppliedDates.contains { calendar.isDate($0, inSameDayAs: d) }
        } ?? false

        return RoundedRectangle(cornerRadius: 2)
            .fill(
                date == nil   ? Color.clear :
                frozen        ? Color.blue.opacity(0.55) :
                completed     ? Color.emerald.opacity(0.85) :
                                Color.slateBorder.opacity(0.5)
            )
            .frame(width: 14, height: 14)
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges Earned").font(.headline).foregroundColor(.white)
            HStack(spacing: 20) {
                ForEach(habit.earnedBadges.sorted(), id: \.self) { m in
                    VStack(spacing: 4) {
                        Text(badgeEmoji(m)).font(.largeTitle)
                        Text("\(m)-day").font(.caption2).foregroundColor(.slateText)
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private func badgeEmoji(_ milestone: Int) -> String {
        switch milestone {
        case 7:   return "🥉"
        case 30:  return "🥈"
        case 100: return "🥇"
        default:  return "⭐️"
        }
    }
}
