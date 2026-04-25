import Foundation

/// Shared App Group identifier — backs the Home Screen widgets.
///
/// The main app writes a small JSON snapshot (see `WidgetSnapshot`) to the
/// shared `UserDefaults` suite under this group, and the widget extension
/// reads it to render. Both targets must declare this group in their
/// `.entitlements` under `com.apple.security.application-groups`, and the
/// App Group must be created in the developer portal under the same ID.
///
/// Why a UserDefaults snapshot rather than sharing the SwiftData store:
///   - The store is backed by `NSPersistentCloudKitContainer`. App Group
///     containers + CloudKit sync work, but the configuration is brittle
///     (history-tracking flags, NSPersistentHistoryToken plumbing, locked
///     read/write contention with the app process). Widgets only need a
///     tiny subset of state (~5 fields), so a snapshot is far cheaper and
///     more reliable.
///   - Widget timelines are built off-process by `widgetextensiond`. Even
///     a successful SwiftData read is slow vs. a single `UserDefaults`
///     dictionary lookup — and the timeline budget (~10s, ~30MB) is tight.
///   - Snapshot writes happen on the main app's save paths (see
///     `WidgetSnapshot.refresh`) and call `WidgetCenter.reloadAllTimelines()`,
///     so the widget always sees fresh data after a relevant mutation.
enum AppGroup {
    static let identifier = "group.com.danieldavis16.fittrack"

    /// Shared `UserDefaults` suite for cross-process reads/writes.
    /// Falls back to `.standard` if the suite can't be opened — happens
    /// in the simulator before the App Group is provisioned, so the
    /// main app keeps working even when the entitlement is missing.
    static let userDefaults: UserDefaults = {
        UserDefaults(suiteName: identifier) ?? .standard
    }()
}
