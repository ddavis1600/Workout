import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(Tab.dashboard)

            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell.fill")
                }
                .tag(Tab.workouts)

            ProgressChartView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle.fill")
                }
                .tag(Tab.habits)

            WeightTrackingView()
                .tabItem {
                    Label("Weight", systemImage: "scalemass.fill")
                }
                .tag(Tab.weight)

            MacrosView()
                .tabItem {
                    Label("Macros", systemImage: "chart.pie.fill")
                }
                .tag(Tab.macros)

            DiaryView()
                .tabItem {
                    Label("Diary", systemImage: "book.fill")
                }
                .tag(Tab.diary)
        }
        .tint(.emerald)
        .preferredColorScheme(.dark)
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
