import SwiftUI
import SwiftData
import WatchConnectivity

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case dashboard, workouts, habits, weight, diary, journal, heartRate, measurements, photos, settings

        var icon: String {
            switch self {
            case .dashboard:    return "house.fill"
            case .workouts:     return "dumbbell.fill"
            case .habits:       return "checkmark.circle.fill"
            case .weight:       return "scalemass.fill"
            case .diary:        return "book.fill"
            case .journal:      return "book.closed.fill"
            case .heartRate:    return "heart.fill"
            case .measurements: return "ruler"
            case .photos:       return "photo.on.rectangle.angled"
            case .settings:     return "gearshape.fill"
            }
        }

        var label: String {
            switch self {
            case .dashboard:    return "Home"
            case .workouts:     return "Workouts"
            case .habits:       return "Habits"
            case .weight:       return "Weight"
            case .diary:        return "Diary"
            case .journal:      return "Journal"
            case .heartRate:    return "Heart"
            case .measurements: return "Measure"
            case .photos:       return "Photos"
            case .settings:     return "Settings"
            }
        }

        var storageKey: String { "tab_\(rawValue)" }
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var showSplash = true
    @AppStorage("appTheme")               private var appTheme     = "system"
    @AppStorage("colorTheme")             private var colorTheme   = "fieldNotes"
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @ObservedObject private var session = WorkoutSessionManager.shared

    // Tab visibility from UserDefaults
    @AppStorage("tab_dashboard")    private var showDashboard    = true
    @AppStorage("tab_workouts")     private var showWorkouts     = true
    @AppStorage("tab_habits")       private var showHabits       = true
    @AppStorage("tab_weight")       private var showWeight       = true
    @AppStorage("tab_diary")        private var showDiary        = true
    @AppStorage("tab_journal")      private var showJournal      = true
    @AppStorage("tab_heartRate")    private var showHeartRate    = true
    @AppStorage("tab_measurements") private var showMeasurements = true
    @AppStorage("tab_photos")       private var showPhotos       = true

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = []
        if showDashboard    { tabs.append(.dashboard) }
        if showWorkouts     { tabs.append(.workouts) }
        if showHabits       { tabs.append(.habits) }
        if showWeight       { tabs.append(.weight) }
        if showDiary        { tabs.append(.diary) }
        if showJournal      { tabs.append(.journal) }
        if showHeartRate    { tabs.append(.heartRate) }
        if showMeasurements { tabs.append(.measurements) }
        if showPhotos       { tabs.append(.photos) }
        tabs.append(.settings)
        return tabs
    }

    var body: some View {
        ZStack {
            tabBody

            // Intro splash (item 9): shown on every launch, auto-dismisses
            // after 2.5s. Sits above everything including the tab bar so
            // the first-launch experience is just icon → app.
            if showSplash {
                IntroSplashView()
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        VStack(spacing: 0) {
            tabContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Persistent mini bar for a minimized workout. Renders inline
            // between the tab content and the tab bar so both stay tappable.
            if session.isActive && session.isMinimized {
                MiniWorkoutBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

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
        .preferredColorScheme(appTheme == "system" ? nil : appTheme == "dark" ? .dark : .light)
        .id(colorTheme + appTheme)   // re-render when palette or brightness changes
        .fullScreenCover(isPresented: .init(
            get: { !hasCompleted },
            set: { if $0 == false { hasCompleted = true } }
        )) {
            OnboardingView()
        }
        // Workout logger lives here (not in WorkoutListView) so it can be
        // started from Dashboard, Workouts, or a watch trigger, and so the
        // fullScreenCover <-> mini bar transition is a single state toggle.
        .fullScreenCover(isPresented: Binding(
            get: { session.isActive && !session.isMinimized },
            set: { newValue in
                // Let users swipe-down or system gestures minimize instead
                // of dismissing — preserves the workout.
                if !newValue && session.isActive { session.minimize() }
            }
        )) {
            LogWorkoutView()
        }
        .animation(.easeInOut(duration: 0.2), value: session.isMinimized)
        .onChange(of: visibleTabs) { _, newTabs in
            if !newTabs.contains(selectedTab) {
                selectedTab = newTabs.first ?? .settings
            }
        }
        .onChange(of: watchManager.pendingWorkoutStart) { _, newValue in
            if newValue {
                selectedTab = .workouts
                watchManager.pendingWorkoutStart = false
                // Kick off the logger so the watch trigger opens the same
                // session UI as the in-app "+" button.
                session.start()
                // Apply the workout type that came from the watch (if any),
                // so the distance field in LogWorkoutView is already set up
                // correctly when the user opens it.
                if let t = watchManager.pendingWorkoutType, !t.isEmpty {
                    session.workoutType = t
                    watchManager.pendingWorkoutType = nil
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .dashboard:    DashboardView()
        case .workouts:     WorkoutListView()
        case .habits:       HabitsView()
        case .weight:       WeightTrackingView()
        case .diary:        DiaryView()
        case .journal:      JournalView()
        case .heartRate:    HeartRateView()
        case .measurements: BodyMeasurementsView()
        case .photos:       ProgressPhotoTimelineView()
        case .settings:     SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Exercise.self, Workout.self, WorkoutSet.self,
            UserProfile.self, Food.self, DiaryEntry.self,
            Habit.self, HabitCompletion.self,
            WeightEntry.self, JournalEntry.self,
            WorkoutTemplate.self, TemplateExercise.self,
            BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
        ], inMemory: true)
}
