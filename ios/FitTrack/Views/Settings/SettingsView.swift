import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    // Theme
    @AppStorage("appTheme")   private var appTheme   = "system"
    @AppStorage("colorTheme") private var colorTheme = "fieldNotes"

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

    /// Read/write binding to the current UserProfile's unitSystem. If no
    /// profile exists yet, creating one on first write is cleaner than
    /// showing an empty picker.
    private var unitSystemBinding: Binding<String> {
        Binding(
            get: { profiles.first?.unitSystem ?? "imperial" },
            set: { newValue in
                if let existing = profiles.first {
                    existing.unitSystem = newValue
                } else {
                    let p = UserProfile()
                    p.unitSystem = newValue
                    modelContext.insert(p)
                }
                modelContext.saveOrLog("SettingsView.unitSystemBinding")
            }
        )
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

                // Units section (item 1).
                // Binds directly to the UserProfile.unitSystem string.
                // UserProfile's displayWeight / setWeight(fromDisplay:) helpers
                // (UserProfile.swift:81-98) handle the kg↔lb / cm↔in conversions
                // downstream — flipping this control updates every view that
                // uses those helpers on the next render.
                Section {
                    Picker(selection: unitSystemBinding) {
                        Text("Imperial (lb, in)").tag("imperial")
                        Text("Metric (kg, cm)").tag("metric")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Units")
                                .foregroundColor(Color.ink)
                        }
                    }
                    .tint(.emerald)
                    .listRowBackground(Color.slateCard)
                } header: {
                    Text("Units")
                        .foregroundColor(.slateText)
                } footer: {
                    Text("Applies to weight entries, body measurements, and macro calculator inputs.")
                        .foregroundColor(.slateText)
                }

                Section {
                    // Colour palette grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colour Palette")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.ink)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                            GridItem(.flexible())], spacing: 10) {
                            ForEach(ThemePalette.allCases) { palette in
                                ThemeSwatchButton(
                                    palette: palette,
                                    isSelected: colorTheme == palette.rawValue
                                ) {
                                    colorTheme = palette.rawValue
                                    applyAlternateIcon(for: palette)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.slateCard)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    // Brightness picker
                    Picker(selection: $appTheme) {
                        Label("Light",  systemImage: "sun.max.fill").tag("light")
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Dark",   systemImage: "moon.fill").tag("dark")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: appTheme == "dark" ? "moon.fill"
                                           : appTheme == "light" ? "sun.max.fill"
                                           : "circle.lefthalf.filled")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Brightness")
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
                        ShortcutsSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.emerald)
                                .frame(width: 24)
                            Text("Siri & Shortcuts")
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
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func applyAlternateIcon(for palette: ThemePalette) {
        let iconName: String? = palette == .fieldNotes ? nil : "AppIcon-\(palette.rawValue)"
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(iconName)
    }
}

// MARK: - Theme Swatch Button

struct ThemeSwatchButton: View {
    let palette: ThemePalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Mini colour swatch
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(palette.bgLight))
                        .frame(height: 52)
                        .overlay(
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(palette.accentLight))
                                    .frame(height: 8)
                                    .padding(.horizontal, 8)
                                HStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(palette.cardLight))
                                        .frame(height: 14)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(palette.cardLight))
                                        .frame(height: 14)
                                }
                                .padding(.horizontal, 8)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color(palette.accentLight) : Color(palette.borderLight),
                                        lineWidth: isSelected ? 2 : 1)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(palette.accentLight))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(4)
                    }
                }

                Text(palette.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.emerald : Color.slateText)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
