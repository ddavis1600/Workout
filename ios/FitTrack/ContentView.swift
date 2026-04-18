import SwiftUI
import SwiftData
import WatchConnectivity

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, progress, habits, weight, macros, diary, journal, heartRate, measurements, photos, settings

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
            case .photos: return "photo.on.rectangle.angled"
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
            case .photos: return "Photos"
            case .settings: return "Settings"
            }
        }

        var storageKey: String { "tab_\(rawValue)" }
    }

    @State private var selectedTab: Tab = .dashboard
    @AppStorage("appTheme") private var appTheme = "light"
    @ObservedObject private var watchManager = WatchConnectivityManager.shared

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
    @AppStorage("tab_photos") private var showPhotos = true
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
        if showPhotos { tabs.append(.photos) }
        tabs.append(.settings) // Settings always visible
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            tabContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom scrollable tab bar
            Divider()
                .overlay(Color.slateBorder)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(visibleTabs, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18))
                                Text(tab.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(selectedTab == tab ? Color.emerald : Color.slateText)
                            .frame(width: 64, height: 48)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .background(Color.slateCard)
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.light)
        .onChange(of: visibleTabs) { _, newTabs in
            if !newTabs.contains(selectedTab) {
                selectedTab = newTabs.first ?? .settings
            }
        }
        .onChange(of: watchManager.pendingWorkoutStart) { _, newValue in
            if newValue {
                selectedTab = .workouts
                watchManager.pendingWorkoutStart = false
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
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
        case .photos:    ProgressPhotoTimelineView()
        case .settings:  SettingsView()
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
            BodyMeasurement.self,
            FoodFavorite.self,
            ProgressPhoto.self,
        ], inMemory: true)
}
