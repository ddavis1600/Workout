import Foundation
import SwiftUI

/// Persistence model for the Health Dashboard's per-user
/// customization (Phase C — F-customize).
///
/// Two pieces of state, both stored as comma-separated metric IDs
/// in `@AppStorage` (UserDefaults under the hood):
///
/// - `dashboard.hiddenCards` — global set of metric IDs the user
///   has chosen to hide. The dashboard filters these out; Settings
///   exposes them in a "Hidden cards" list so they can be un-hidden.
/// - `dashboard.cardOrder.<tier>` — per-tier ordered list of metric
///   IDs. Cards in the list render in that order; cards NOT in the
///   list (e.g. a brand-new metric introduced in a future build)
///   render after, in the order they appear in `HealthMetric.all`.
///
/// CSV is fine for the storage shape because metric IDs are stable
/// short identifiers (`"sleep"`, `"hrv"`, …). Switching to a JSON-
/// encoded array would buy us nothing and complicate `@AppStorage`
/// (which only supports a fixed set of element types).
enum DashboardCustomization {
    static let hiddenKey = "dashboard.hiddenCards"

    static func orderKey(for tier: HealthMetric.Tier) -> String {
        "dashboard.cardOrder.\(tier.rawValue)"
    }

    // MARK: Decoding helpers

    static func decode(_ csv: String) -> [String] {
        guard !csv.isEmpty else { return [] }
        return csv.split(separator: ",").map(String.init)
    }

    static func encode(_ ids: [String]) -> String {
        ids.joined(separator: ",")
    }

    // MARK: Apply order to a candidate list

    /// Apply the user's saved order to `cards`. Cards present in the
    /// saved order render first in that order; any leftovers (newly-
    /// added catalog entries the user hasn't ordered yet) tail the
    /// list in their original catalog order.
    static func ordered(
        _ cards: [MetricSummary],
        order: [String]
    ) -> [MetricSummary] {
        guard !order.isEmpty else { return cards }
        var byId = Dictionary(uniqueKeysWithValues: cards.map { ($0.metric.id, $0) })
        var result: [MetricSummary] = []
        for id in order {
            if let s = byId.removeValue(forKey: id) {
                result.append(s)
            }
        }
        // Anything not in the saved order — typically a new metric
        // added in a future build — keeps its catalog ordering.
        for card in cards where byId[card.metric.id] != nil {
            result.append(card)
        }
        return result
    }
}
