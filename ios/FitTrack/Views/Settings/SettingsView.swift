import SwiftUI

struct SettingsView: View {
    // Theme
    @AppStorage("appTheme") private var appTheme = "light"

    // Rest timer
    @AppStorage("restTimerEnabled") private var restTimerEnabled = true
    @AppStorage("restTimerSeconds") private var restTimerSeconds = 60

    // Diary
    @AppStorage("showNetCarbs") private var showNetCarbs = false

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
    @AppStorage("tab_measurements") private var showMeasurements = true
    @AppStorage("tab_photos") private var showPhotos = true

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
            ("measurements", "Measurements", "ruler", $showMeasurements),
            ("photos", "Progress Photos", "photo.on.rectangle.angled", $showPhotos),
        ]
    }

    private var enabledCount: Int {
        [showDashboard, showWorkouts, showProgress, showHabits, showWeight, showMacros, showDiary, showJournal, showHeartRate, showMeasurements, showPhotos].filter { $0 }.count
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
                                    .foregroundColor(Color.ink)
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
                    Toggle(isOn: $restTimerEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Rest Timer")
                                .foregroundColor(Color.ink)
                        }
                    }
                    .tint(.emerald)
                    .listRowBackground(Color.slateCard)

                    if restTimerEnabled {
                        Picker(selection: $restTimerSeconds) {
                            Text("30s").tag(30)
                            Text("45s").tag(45)
                            Text("60s").tag(60)
                            Text("90s").tag(90)
                            Text("120s").tag(120)
                            Text("180s").tag(180)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundColor(.emerald)
                                    .frame(width: 24)
                                Text("Duration")
                                    .foregroundColor(Color.ink)
                            }
                        }
                        .tint(.emerald)
                        .listRowBackground(Color.slateCard)
                    }
                } header: {
                    Text("Workout")
                        .foregroundColor(.slateText)
                }

                Section {
                    Toggle(isOn: $showNetCarbs) {
                        HStack(spacing: 12) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Net Carbs")
                                    .foregroundColor(Color.ink)
                                Text("Subtracts fiber from carbs in all displays")
                                    .font(.caption)
                                    .foregroundColor(.slateText)
                            }
                        }
                    }
                    .tint(.emerald)
                    .listRowBackground(Color.slateCard)
                } header: {
                    Text("Diary")
                        .foregroundColor(.slateText)
                }

                Section {
                    Picker(selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: appTheme == "dark" ? "moon.fill" : appTheme == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Theme")
                                .foregroundColor(Color.ink)
                        }
                    }
                    .tint(.emerald)
                    .listRowBackground(Color.slateCard)
                } header: {
                    Text("Appearance")
                        .foregroundColor(.slateText)
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Notifications")
                                .foregroundColor(Color.ink)
                        }
                    }
                    .listRowBackground(Color.slateCard)

                    NavigationLink {
                        DataExportView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Export Data")
                                .foregroundColor(Color.ink)
                        }
                    }
                    .listRowBackground(Color.slateCard)
                } header: {
                    Text("Data & Notifications")
                        .foregroundColor(.slateText)
                }

                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(Color.ink)
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
