import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area - fills entire screen
            currentTabView
                .padding(.bottom, 56)

            // Custom tab bar pinned to bottom
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
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
        .padding(.bottom, 28)
        .background(
            Color(red: 0.11, green: 0.13, blue: 0.17)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
        )
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
