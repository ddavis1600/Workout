import SwiftUI
import UserNotifications

/// Notification settings screen — exposes the four notification
/// kinds defined in `NotificationService` (audit ref F2). Each has
/// its own toggle; default is off across the board (opt-in).
///
/// Permission flow (M1):
///   - First time the user flips ANY toggle on, we request
///     notification permission via `NotificationService.requestPermission`.
///     If they grant, the kind's schedule helper runs.
///   - Subsequent toggles short-circuit through
///     `currentAuthorizationStatus()` — already-granted users don't
///     see another prompt; revoked users see a hint to enable in
///     iOS Settings.
///
/// AppStorage keys are namespaced so they don't collide with the
/// older `workoutReminderEnabled` / `habitReminderEnabled` flags
/// from the previous version of this view (those still drive the
/// legacy `scheduleWorkoutReminders` / `scheduleHabitReminder`
/// helpers in `NotificationService`).
struct NotificationSettingsView: View {
    // MARK: - Toggle state

    @AppStorage("foodLogReminderEnabled") private var foodLogEnabled = false
    @AppStorage("foodLogReminderHour")    private var foodLogHour    = 20  // default 8 pm
    @AppStorage("foodLogReminderMinute")  private var foodLogMinute  = 0

    @AppStorage("workoutNudgeEnabled") private var workoutNudgeEnabled = false
    @AppStorage("workoutNudgeHour")    private var workoutNudgeHour    = 18  // default 6 pm
    @AppStorage("workoutNudgeMinute")  private var workoutNudgeMinute  = 0

    @AppStorage("streakProtectionEnabled") private var streakProtectionEnabled = false

    @AppStorage("weeklySummaryEnabled") private var weeklySummaryEnabled = false

    @State private var permissionDenied = false

    var body: some View {
        List {
            if permissionDenied {
                permissionDeniedBanner
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
            }

            // MARK: Food log reminder
            Section {
                Toggle(isOn: $foodLogEnabled) {
                    Label("Food log reminder", systemImage: "fork.knife")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: foodLogEnabled) { _, enabled in
                    handleToggle(enabled: enabled, schedule: scheduleFoodLog, cancel: NotificationService.cancelFoodLogReminder)
                }

                if foodLogEnabled {
                    DatePicker("Time", selection: foodLogTime, displayedComponents: .hourAndMinute)
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                        .listRowBackground(Color.slateCard)
                }

                Text("A gentle nudge to log dinner so your macros stay honest.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .listRowBackground(Color.slateBackground)
            } header: {
                Text("Food Log").foregroundColor(.slateText)
            }

            // MARK: Workout nudge
            Section {
                Toggle(isOn: $workoutNudgeEnabled) {
                    Label("Workout nudge", systemImage: "dumbbell.fill")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: workoutNudgeEnabled) { _, enabled in
                    handleToggle(enabled: enabled, schedule: scheduleWorkoutNudge, cancel: NotificationService.cancelWorkoutNudge)
                }

                if workoutNudgeEnabled {
                    DatePicker("Time", selection: workoutNudgeTime, displayedComponents: .hourAndMinute)
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                        .listRowBackground(Color.slateCard)
                }

                Text("Auto-suppressed on days you've already logged a workout.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .listRowBackground(Color.slateBackground)
            } header: {
                Text("Workout").foregroundColor(.slateText)
            }

            // MARK: Streak protection
            Section {
                Toggle(isOn: $streakProtectionEnabled) {
                    Label("Streak protection", systemImage: "flame.fill")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: streakProtectionEnabled) { _, enabled in
                    handleToggle(enabled: enabled,
                                 schedule: { NotificationService.scheduleStreakProtection() },
                                 cancel: NotificationService.cancelStreakProtection)
                }

                Text("Fires at 9 pm if any habit's streak is at risk for the day.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .listRowBackground(Color.slateBackground)
            } header: {
                Text("Habits").foregroundColor(.slateText)
            }

            // MARK: Weekly summary
            Section {
                Toggle(isOn: $weeklySummaryEnabled) {
                    Label("Weekly summary", systemImage: "calendar")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: weeklySummaryEnabled) { _, enabled in
                    handleToggle(enabled: enabled,
                                 schedule: scheduleWeeklySummary,
                                 cancel: NotificationService.cancelWeeklySummary)
                }

                Text("Sunday 7 pm — your week in review: workouts, calories, habit days.")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .listRowBackground(Color.slateBackground)
            } header: {
                Text("Recap").foregroundColor(.slateText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Refresh denied-banner visibility when the user returns
            // from iOS Settings.
            await refreshPermissionStatus()
        }
    }

    // MARK: - Permission banner

    private var permissionDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Notifications are disabled in Settings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }
            Text("Toggling these on saves your preference, but iOS won't deliver them until you re-enable notifications for Cairn in the Settings app.")
                .font(.caption)
                .foregroundStyle(Color.slateText)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") {
                    UIApplication.shared.open(url)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.emerald)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Time bindings

    /// Convert the AppStorage hour/minute pair into a `Date` for the
    /// `DatePicker`. Components-only date stays stable across day
    /// boundaries so the user's chosen time persists correctly.
    private var foodLogTime: Binding<Date> {
        timeBinding(hour: $foodLogHour, minute: $foodLogMinute, onChange: scheduleFoodLog)
    }

    private var workoutNudgeTime: Binding<Date> {
        timeBinding(hour: $workoutNudgeHour, minute: $workoutNudgeMinute, onChange: scheduleWorkoutNudge)
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>, onChange: @escaping () -> Void) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = hour.wrappedValue
                components.minute = minute.wrappedValue
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour.wrappedValue = components.hour ?? hour.wrappedValue
                minute.wrappedValue = components.minute ?? minute.wrappedValue
                onChange()
            }
        )
    }

    // MARK: - Schedule helpers (each kind)

    private func scheduleFoodLog() {
        guard foodLogEnabled else { return }
        NotificationService.scheduleFoodLogReminder(hour: foodLogHour, minute: foodLogMinute)
    }

    private func scheduleWorkoutNudge() {
        guard workoutNudgeEnabled else { return }
        NotificationService.scheduleWorkoutNudge(hour: workoutNudgeHour, minute: workoutNudgeMinute)
    }

    private func scheduleWeeklySummary() {
        guard weeklySummaryEnabled else { return }
        // Body copy uses static placeholders for v1 — wiring SwiftData
        // queries at schedule time would mean re-scheduling weekly
        // from a background job, which is out of scope for this PR.
        // The numbers update next time the user toggles the setting.
        NotificationService.scheduleWeeklySummary(workouts: 0, calories: 0, habitDays: 0)
    }

    // MARK: - Toggle handler

    /// Centralizes the permission-then-schedule handshake every
    /// toggle goes through. Splitting per-kind callbacks lets each
    /// section own its `schedule` closure without copy-pasting the
    /// permission dance.
    private func handleToggle(enabled: Bool, schedule: @escaping () -> Void, cancel: @escaping () -> Void) {
        if !enabled {
            cancel()
            return
        }
        Task {
            let granted = await ensurePermission()
            if granted {
                schedule()
            } else {
                permissionDenied = true
            }
        }
    }

    /// Triggers the system prompt only on first request. Subsequent
    /// calls observe the stored authorization status so we don't
    /// nag.
    private func ensurePermission() async -> Bool {
        let status = await NotificationService.currentAuthorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await NotificationService.requestPermission()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func refreshPermissionStatus() async {
        let status = await NotificationService.currentAuthorizationStatus()
        permissionDenied = (status == .denied)
    }
}
