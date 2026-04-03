import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch selectedTab {
                case .dashboard: DashboardView()
                case .workouts:  WorkoutListView()
                case .progress:  ProgressChartView()
                case .habits:    HabitsView()
                case .weight:    WeightTrackingView()
                case .macros:    MacrosView()
                case .diary:     DiaryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            customTabBar
        }
        .preferredColorScheme(.dark)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.dashboard, icon: "house.fill", label: "Home")
            tabButton(.workouts, icon: "dumbbell.fill", label: "Workouts")
            tabButton(.progress, icon: "chart.line.uptrend.xyaxis", label: "Progress")
            tabButton(.habits, icon: "checkmark.circle.fill", label: "Habits")
            tabButton(.weight, icon: "scalemass.fill", label: "Weight")
            tabButton(.macros, icon: "chart.pie.fill", label: "Macros")
            tabButton(.diary, icon: "book.fill", label: "Diary")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            Color(red: 0.11, green: 0.13, blue: 0.17)
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
        )
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.emerald : Color.slateText)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Exercise.self,
            Workout.self,
            WorkoutSet.self,
            UserProfile.self,
            Food.self,
            DiaryEntry.self,
            Habit.self,
            HabitCompletion.self,
            WeightEntry.self
        ], inMemory: true)
}
