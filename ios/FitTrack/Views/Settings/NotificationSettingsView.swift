import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("workoutReminderEnabled") private var workoutReminderEnabled = false
    @AppStorage("workoutReminderHour") private var workoutReminderHour = 8
    @AppStorage("workoutReminderMinute") private var workoutReminderMinute = 0
    @AppStorage("workoutReminderDays") private var workoutReminderDays = "2,3,4,5,6" // Mon-Fri

    @AppStorage("habitReminderEnabled") private var habitReminderEnabled = false
    @AppStorage("habitReminderHour") private var habitReminderHour = 20
    @AppStorage("habitReminderMinute") private var habitReminderMinute = 0

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var selectedDays: Set<Int> {
        Set(workoutReminderDays.split(separator: ",").compactMap { Int($0) })
    }

    private var workoutTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = workoutReminderHour
                components.minute = workoutReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                workoutReminderHour = components.hour ?? 8
                workoutReminderMinute = components.minute ?? 0
                updateWorkoutReminders()
            }
        )
    }

    private var habitTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = habitReminderHour
                components.minute = habitReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                habitReminderHour = components.hour ?? 20
                habitReminderMinute = components.minute ?? 0
                updateHabitReminder()
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $workoutReminderEnabled) {
                    Label("Workout Reminders", systemImage: "dumbbell.fill")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: workoutReminderEnabled) { _, enabled in
                    if enabled {
                        NotificationService.requestPermission()
                        updateWorkoutReminders()
                    } else {
                        let ids = (1...7).map { "workout_reminder_\($0)" }
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                    }
                }

                if workoutReminderEnabled {
                    DatePicker("Time", selection: workoutTime, displayedComponents: .hourAndMinute)
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                        .listRowBackground(Color.slateCard)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Days")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)

                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { day in
                                let isSelected = selectedDays.contains(day)
                                Button {
                                    toggleDay(day)
                                } label: {
                                    Text(dayNames[day - 1])
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(width: 36, height: 36)
                                        .background(isSelected ? Color.emerald : Color.slateBackground)
                                        .foregroundStyle(isSelected ? Color.paper : Color.slateText)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.slateCard)
                }
            } header: {
                Text("Workout Reminders")
                    .foregroundColor(.slateText)
            }

            Section {
                Toggle(isOn: $habitReminderEnabled) {
                    Label("Habit Reminders", systemImage: "checkmark.circle.fill")
                        .foregroundColor(Color.ink)
                }
                .tint(.emerald)
                .listRowBackground(Color.slateCard)
                .onChange(of: habitReminderEnabled) { _, enabled in
                    if enabled {
                        NotificationService.requestPermission()
                        updateHabitReminder()
                    } else {
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["habit_reminder"])
                    }
                }

                if habitReminderEnabled {
                    DatePicker("Time", selection: habitTime, displayedComponents: .hourAndMinute)
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                        .listRowBackground(Color.slateCard)
                }
            } header: {
                Text("Habit Reminders")
                    .foregroundColor(.slateText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleDay(_ day: Int) {
        var days = selectedDays
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
        workoutReminderDays = days.sorted().map(String.init).joined(separator: ",")
        updateWorkoutReminders()
    }

    private func updateWorkoutReminders() {
        guard workoutReminderEnabled else { return }
        NotificationService.scheduleWorkoutReminders(
            days: selectedDays,
            hour: workoutReminderHour,
            minute: workoutReminderMinute
        )
    }

    private func updateHabitReminder() {
        guard habitReminderEnabled else { return }
        NotificationService.scheduleHabitReminder(hour: habitReminderHour, minute: habitReminderMinute)
    }
}
