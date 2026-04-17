import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleWorkoutReminders(days: Set<Int>, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "workout_reminder_\($0)" })

        for day in days {
            var components = DateComponents()
            components.weekday = day
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Time to Work Out!"
            content.body = "Don't skip your workout today. Stay consistent!"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "workout_reminder_\(day)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func scheduleHabitReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["habit_reminder"])

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Check Your Habits"
        content.body = "Have you completed your habits for today?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "habit_reminder",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // Per-habit notification keyed by the habit's creation timestamp
    static func scheduleHabitNotification(habitKey: String, name: String, scheduledDays: [Int], reminderTime: Date) {
        let center = UNUserNotificationCenter.current()
        let ids = (0...6).map { "habit_\(habitKey)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let cal = Calendar.current
        let hour = cal.component(.hour, from: reminderTime)
        let minute = cal.component(.minute, from: reminderTime)

        let days = scheduledDays.isEmpty ? Array(0...6) : scheduledDays // 0=Sun…6=Sat
        for day in days {
            var components = DateComponents()
            components.weekday = day + 1 // UNCalendar: 1=Sun…7=Sat
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Habit Reminder"
            content.body = "Time for: \(name)"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "habit_\(habitKey)_\(day)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func cancelHabitNotification(habitKey: String) {
        let ids = (0...6).map { "habit_\(habitKey)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
