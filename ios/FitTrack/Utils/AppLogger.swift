import Foundation
import OSLog
import SwiftData

/// Centralized logger. Use `AppLogger.<category>` anywhere in the app to
/// get a pre-configured `Logger` you can `.error(...)`, `.warning(...)`,
/// etc. on.
///
/// `subsystem` is the app's bundle id; `category` lets Console.app
/// filter (e.g. "Subsystem: com.fittrack category: storage").
///
/// Why OSLog instead of `print`:
///   - captured in `Console.app` + device logs sysdiagnose, so beta
///     crash reports actually include the trail.
///   - off-process — logging doesn't block the caller's actor, which
///     matters in the main-thread save paths we're instrumenting.
///   - respects Privacy filtering. We pass user-data types like
///     `error.localizedDescription` as `public` deliberately, since
///     the description won't include PII — just SwiftData / CloudKit
///     error codes.
enum AppLogger {
    private static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "com.fittrack"
    }()

    /// SwiftData save / fetch / migration failures.
    static let storage = Logger(subsystem: subsystem, category: "storage")

    /// HealthKit auth + query failures (already partially logged to
    /// `print` in `HealthKitManager`; this is the target once those
    /// get converted).
    static let health = Logger(subsystem: subsystem, category: "health")

    /// CloudKit-specific failures distinct from plain SwiftData ones
    /// (e.g. NSPersistentCloudKitContainer init failures).
    static let cloudkit = Logger(subsystem: subsystem, category: "cloudkit")

    /// WatchConnectivity session / message errors.
    static let watch = Logger(subsystem: subsystem, category: "watch")
}

// MARK: - ModelContext.saveOrLog

extension ModelContext {
    /// Drop-in replacement for `try? modelContext.save()` that surfaces
    /// the failure to OSLog instead of silently swallowing it.
    ///
    /// Usage:
    ///     modelContext.saveOrLog("deleteWorkout")
    ///
    /// The label flows into the log message so Console triage can tell
    /// "habit delete failed" from "diary entry save failed" without
    /// scraping stack frames. File/line are captured automatically
    /// via `#fileID` / `#line` for deep-link-in-Xcode jumping.
    ///
    /// Callers that need to react to a failure (e.g. show a toast,
    /// roll back UI state) should use `try modelContext.save()` with
    /// a do/catch directly. This helper is for the 40+ fire-and-forget
    /// sites where previously a `try?` swallowed the error entirely.
    @discardableResult
    func saveOrLog(
        _ label: String,
        file: String = #fileID,
        line: Int = #line
    ) -> Bool {
        do {
            try save()
            return true
        } catch {
            AppLogger.storage.error(
                "save failed (\(label, privacy: .public)) at \(file, privacy: .public):\(line): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
