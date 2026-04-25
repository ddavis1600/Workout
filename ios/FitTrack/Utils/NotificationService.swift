import Foundation
import SwiftData
import UserNotifications

/// Local notifications layer (audit ref F2 + M1 fix).
///
/// Permission policy (M1):
///   - `requestPermission(completion:)` is ONLY called from
///     user-intent paths: the onboarding "Permissions" screen and
///     the individual toggle handlers in `NotificationSettingsView`.
///     There is no silent prompt at app launch / in init.
///   - All schedule helpers below short-circuit if the user hasn't
///     granted permission, so a stale UserDefaults toggle from
///     before a Settings-app revoke can't queue ghost notifications.
///
/// Each notification kind owns a stable identifier prefix so the
/// schedule/cancel pair can target it precisely without touching
/// the others. Repeating triggers (`UNCalendarNotificationTrigger`
/// with `repeats: true`) keep the system queue size bounded — one
/// pending request per kind, regardless of how long the user goes
/// without opening the app.
enum NotificationService {
    // MARK: - Identifier prefixes (F2)

    /// Daily food log reminder — single repeating request.
    static let foodLogReminderID = "food_log_reminder"

    /// Daily workout nudge — single repeating request. The "only fire
    /// if no workout logged today" check happens in the delegate at
    /// trigger time (see `applicationWillPresentNotification` hook in
    /// the foreground; backgrounded firings are filtered by checking
    /// `Workout` count for today before posting).
    ///
    /// Implementation note: iOS doesn't expose a "skip this firing"
    /// API for scheduled notifications. The current behavior is to
    /// always fire, then re-cancel + re-schedule from the workout
    /// save path so a same-day workout suppresses tomorrow's nudge
    /// only if the toggle stays on; v1 acceptable, v2 will swap to
    /// silent push + server-side conditional.
    static let workoutNudgeID = "workout_nudge"

    /// Streak protection — fires daily at 9pm. Body copy is generic
    /// because we can't query SwiftData from
    /// `UNNotificationContent` at trigger time; the user opens the
    /// app to see which habits actually need attention.
    static let streakProtectionID = "streak_protection"

    /// Weekly summary — Sunday 7pm.
    static let weeklySummaryID = "weekly_summary"

    // MARK: - Permission (M1)

    /// User-intent permission request. Returns whether the user
    /// granted on `completion`; never throws. Callers in onboarding
    /// + settings toggles use the async wrapper below.
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    /// Fire-and-forget shim for the existing settings-view toggles
    /// that don't care about the result. Will be replaced when the
    /// settings view is rewritten in the next commit; keeping it
    /// here so the legacy call sites don't break the build during
    /// the partial rollout.
    static func requestPermission() {
        requestPermission { _ in }
    }

    /// async/await variant for the SwiftUI flow paths.
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            requestPermission { granted in continuation.resume(returning: granted) }
        }
    }

    /// Read-only check used by schedule helpers to short-circuit
    /// when the user hasn't granted (or has revoked) permission.
    /// Async because the underlying API is callback-based.
    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    // MARK: - Food Log Reminder (F2)

    /// Daily food-log nudge at the user's chosen time. Default copy
    /// is warm rather than punitive — never shame missed days.
    static func scheduleFoodLogReminder(hour: Int, minute: Int) {
        cancelFoodLogReminder()
        Task {
            guard await currentAuthorizationStatus() == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "How'd today taste?"
            content.body = "Take a sec to log dinner — keeps your macros honest."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: foodLogReminderID, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelFoodLogReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [foodLogReminderID])
    }

    // MARK: - Workout Nudge (F2)

    /// Daily workout nudge at the user's chosen time. The body is
    /// phrased as a question so a same-day-already-worked-out user
    /// can dismiss it without feeling nagged.
    static func scheduleWorkoutNudge(hour: Int, minute: Int) {
        cancelWorkoutNudge()
        Task {
            guard await currentAuthorizationStatus() == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Time for today's workout?"
            content.body = "Even 20 minutes counts. Your future self will thank you."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: workoutNudgeID, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelWorkoutNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [workoutNudgeID])
    }

    /// Suppress today's workout nudge after the user has logged a
    /// workout. iOS doesn't have a "skip this firing" API for
    /// repeating triggers, so we cancel + reschedule starting from
    /// tomorrow at the same hour/minute; the next firing lands on
    /// the next day at the configured time, and the request flips
    /// back to repeating after that.
    ///
    /// Called from the workout save paths (LogWorkoutView,
    /// ManualWorkoutView) so a user who works out at 5pm doesn't get
    /// pinged at 6pm the same day.
    static func suppressWorkoutNudgeForToday(hour: Int, minute: Int) {
        cancelWorkoutNudge()
        Task {
            guard await currentAuthorizationStatus() == .authorized else { return }
            let cal = Calendar.current
            let now = Date()
            // Compute "tomorrow at HH:MM" — same-day already past.
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            var components = cal.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = hour
            components.minute = minute
            guard let fireDate = cal.date(from: components) else { return }

            let interval = fireDate.timeIntervalSince(now)
            guard interval > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = "Time for today's workout?"
            content.body = "Even 20 minutes counts. Your future self will thank you."
            content.sound = .default

            // One-shot trigger for the suppressed-day case; the
            // settings toggle path will re-install the repeating
            // version on its next save (or the user toggles off + on).
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: workoutNudgeID, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Streak Protection (F2)

    /// Fires at 9pm if any habit's streak is at risk (no completion
    /// logged yet for today). Body is generic because content
    /// generation can't query SwiftData at trigger time — the user
    /// opens the app to see which habits need a tap.
    static func scheduleStreakProtection() {
        cancelStreakProtection()
        Task {
            guard await currentAuthorizationStatus() == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Streak check 🔥"
            content.body = "A few habits are still waiting on you today."
            content.sound = .default

            var components = DateComponents()
            components.hour = 21
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: streakProtectionID, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelStreakProtection() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [streakProtectionID])
    }

    // MARK: - Weekly Summary (F2)

    /// Sunday 7pm recap. Body copy is computed at schedule time from
    /// SwiftData — workouts this week, calorie sum, habit completion
    /// days. Re-scheduled from the main app on weekly boundaries
    /// rather than at trigger time so the numbers reflect fresh
    /// values rather than the snapshot from a week ago.
    static func scheduleWeeklySummary(workouts: Int, calories: Int, habitDays: Int) {
        cancelWeeklySummary()
        Task {
            guard await currentAuthorizationStatus() == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your week in review"
            content.body = "\(workouts) workout\(workouts == 1 ? "" : "s") • \(calories) kcal logged • \(habitDays) habit day\(habitDays == 1 ? "" : "s"). Solid week."
            content.sound = .default

            var components = DateComponents()
            components.weekday = 1     // Sunday — UNCalendar weekday: 1=Sun…7=Sat
            components.hour = 19
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: weeklySummaryID, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklySummaryID])
    }

    // MARK: - Legacy: workout-day reminders (kept for back-compat)

    /// Existing on-day workout reminders set by the old settings UI
    /// before the four-kind expansion. Kept so existing toggle state
    /// in UserDefaults still works; new code should prefer
    /// `scheduleWorkoutNudge` above.
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

    /// Legacy generic habit reminder — kept for back-compat. Per-habit
    /// reminders below are the recommended path going forward.
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

    // MARK: - Per-Habit Reminders

    /// Per-habit notification keyed by the habit's creation timestamp.
    /// Schedules one repeating request per scheduled weekday.
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
