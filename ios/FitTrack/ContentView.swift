import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        currentTabView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                customTabBar
            }
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var currentTabView: some View {
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

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.slateBorder)
            HStack(spacing: 0) {
                tabButton(.dashboard, icon: "house.fill", label: "Home")
                tabButton(.workouts, icon: "dumbbell.fill", label: "Workouts")
                tabButton(.progress, icon: "chart.line.uptrend.xyaxis", label: "Progress")
                tabButton(.habits, icon: "checkmark.circle.fill", label: "Habits")
                tabButton(.weight, icon: "scalemass.fill", label: "Weight")
                tabButton(.macros, icon: "chart.pie.fill", label: "Macros")
                tabButton(.diary, icon: "book.fill", label: "Diary")
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 17))
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
