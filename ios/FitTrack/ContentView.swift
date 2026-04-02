import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, macros, diary
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
            DiaryEntry.self
        ], inMemory: true)
}
