import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary, journal, heartRate, measurements, settings

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .workouts: return "dumbbell.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .habits: return "checkmark.circle.fill"
            case .weight: return "scalemass.fill"
            case .macros: return "chart.pie.fill"
            case .diary: return "book.fill"
            case .journal: return "book.closed.fill"
            case .heartRate: return "heart.fill"
            case .measurements: return "ruler"
            case .settings: return "gearshape.fill"
            }
        }

        var label: String {
            switch self {
            case .dashboard: return "Home"
            case .workouts: return "Workouts"
            case .progress: return "Progress"
            case .habits: return "Habits"
            case .weight: return "Weight"
            case .macros: return "Macros"
            case .diary: return "Diary"
            case .journal: return "Journal"
            case .heartRate: return "Heart"
            case .measurements: return "Measure"
            case .settings: return "Settings"
            }
        }

        var storageKey: String { "tab_\(rawValue)" }
    }

    @State private var selectedTab: Tab = .dashboard
    @AppStorage("appTheme") private var appTheme = "dark"

    // Tab visibility from UserDefaults
    @AppStorage("tab_dashboard") private var showDashboard = true
    @AppStorage("tab_workouts") private var showWorkouts = true
    @AppStorage("tab_progress") private var showProgress = true
    @AppStorage("tab_habits") private var showHabits = true
    @AppStorage("tab_weight") private var showWeight = true
    @AppStorage("tab_macros") private var showMacros = true
    @AppStorage("tab_diary") private var showDiary = true
    @AppStorage("tab_journal") private var showJournal = true
    @AppStorage("tab_heartRate") private var showHeartRate = true
    @AppStorage("tab_measurements") private var showMeasurements = true

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = []
        if showDashboard { tabs.append(.dashboard) }
        if showWorkouts { tabs.append(.workouts) }
        if showProgress { tabs.append(.progress) }
        if showHabits { tabs.append(.habits) }
        if showWeight { tabs.append(.weight) }
        if showMacros { tabs.append(.macros) }
        if showDiary { tabs.append(.diary) }
        if showJournal { tabs.append(.journal) }
        if showHeartRate { tabs.append(.heartRate) }
        if showMeasurements { tabs.append(.measurements) }
        tabs.append(.settings) // Settings always visible
        return tabs
    }

    var body: some View {
        currentTabView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                customTabBar
            }
            .preferredColorScheme(appTheme == "system" ? nil : appTheme == "light" ? .light : .dark)
            .onChange(of: visibleTabs) { _, newTabs in
                // If current tab was hidden, switch to first visible
                if !newTabs.contains(selectedTab) {
                    selectedTab = newTabs.first ?? .settings
                }
            }
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
        case .journal:   JournalView()
        case .heartRate: HeartRateView()
        case .measurements: BodyMeasurementsView()
        case .settings:  SettingsView()
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.slateBorder)
            HStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color(red: 0.11, green: 0.13, blue: 0.17).ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                Text(tab.label)
                    .font(.system(size: 8, weight: .medium))
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
            WeightEntry.self,
            JournalEntry.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            BodyMeasurement.self
        ], inMemory: true)
}
