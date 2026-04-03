import SwiftUI

struct SettingsView: View {
    // Tab visibility — stored in UserDefaults
    @AppStorage("tab_dashboard") private var showDashboard = true
    @AppStorage("tab_workouts") private var showWorkouts = true
    @AppStorage("tab_progress") private var showProgress = true
    @AppStorage("tab_habits") private var showHabits = true
    @AppStorage("tab_weight") private var showWeight = true
    @AppStorage("tab_macros") private var showMacros = true
    @AppStorage("tab_diary") private var showDiary = true
    @AppStorage("tab_journal") private var showJournal = true
    @AppStorage("tab_heartRate") private var showHeartRate = true

    private var tabToggles: [(key: String, label: String, icon: String, binding: Binding<Bool>)] {
        [
            ("dashboard", "Dashboard", "house.fill", $showDashboard),
            ("workouts", "Workouts", "dumbbell.fill", $showWorkouts),
            ("progress", "Progress", "chart.line.uptrend.xyaxis", $showProgress),
            ("habits", "Habits", "checkmark.circle.fill", $showHabits),
            ("weight", "Weight", "scalemass.fill", $showWeight),
            ("macros", "Macros", "chart.pie.fill", $showMacros),
            ("diary", "Food Diary", "book.fill", $showDiary),
            ("journal", "Journal", "book.closed.fill", $showJournal),
            ("heartRate", "Heart Rate", "heart.fill", $showHeartRate),
        ]
    }

    private var enabledCount: Int {
        [showDashboard, showWorkouts, showProgress, showHabits, showWeight, showMacros, showDiary, showJournal, showHeartRate].filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tabToggles, id: \.key) { item in
                        Toggle(isOn: item.binding) {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .foregroundColor(.emerald)
                                    .frame(width: 24)
                                Text(item.label)
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(.emerald)
                        .disabled(item.binding.wrappedValue && enabledCount <= 1)
                        .listRowBackground(Color.slateCard)
                    }
                } header: {
                    Text("Visible Tabs")
                        .foregroundColor(.slateText)
                } footer: {
                    Text("Choose which features appear in the bottom tab bar. At least one must be enabled.")
                        .foregroundColor(.slateText)
                }

                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.slateText)
                    }
                    .listRowBackground(Color.slateCard)
                } header: {
                    Text("About")
                        .foregroundColor(.slateText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
