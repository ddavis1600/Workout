import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleWorkoutReminders(days: Set<Int>, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        // Remove existing workout reminders
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "workout_reminder_\($0)" })

        for day in days {
            var components = DateComponents()
            components.weekday = day // 1=Sunday, 7=Saturday
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

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
