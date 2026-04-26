import WidgetKit
import SwiftUI

/// Single timeline entry shared by all three widgets — each widget renders
/// a different subset of the snapshot fields.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Shared timeline provider — every widget in the bundle reads the same
/// snapshot, so they all use the same provider rather than duplicating
/// the load + scheduling logic.
///
/// Timeline policy: a single entry that expires 30 minutes from now,
/// matching the v1 spec. The main app calls
/// `WidgetCenter.shared.reloadAllTimelines()` whenever the underlying
/// data changes, so most updates land immediately rather than waiting
/// for the next refresh tick.
struct SharedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: WidgetSnapshot.load())
        // Refresh every ~30 minutes. WidgetCenter.reloadAllTimelines() from
        // the main app shortcuts this when the user actually changes data.
        let refreshAt = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
    }
}
