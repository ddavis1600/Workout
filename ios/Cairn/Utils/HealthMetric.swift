import Foundation
import HealthKit

// Static catalog describing each metric the Health Dashboard surfaces.
// Phase A ships the four Core Vitals entries below; Phase B will extend
// `all` with Tier 2 (Fitness) and Tier 3 (Wellness). The service layer
// dispatches HK queries off `aggregation`; the view layer dispatches
// chart rendering off `chart`.
struct HealthMetric: Identifiable, Hashable {
    enum Tier: Int, CaseIterable, Hashable {
        case coreVitals = 1
        case fitness
        case wellness

        var label: String {
            switch self {
            case .coreVitals: return "Core Vitals"
            case .fitness:    return "Fitness"
            case .wellness:   return "Wellness"
            }
        }
    }

    // How the service should aggregate samples into the per-day window
    // the dashboard renders. Drives `HKStatisticsCollectionQuery.options`
    // for quantity types and a custom code path for sleep.
    enum Aggregation: Hashable {
        case sum            // cumulativeSum  — steps, energy
        case average        // discreteAverage — resting HR
        case latest         // most-recent sample — weight
        case sleepCategory  // custom asleepCore/Deep/REM bucketing
    }

    enum Chart: Hashable {
        case sleepStackedBar    // per-night stages (last 7 nights)
        case line               // smoothed line (resting HR, 7d)
        case bar                // bars per day (steps, 7d)
        case weightLine         // smoothed line, 30-day window
    }

    let id: String
    let label: String
    let icon: String
    let unit: String
    let tier: Tier
    let aggregation: Aggregation
    let chart: Chart
    let hkQuantity: HKQuantityTypeIdentifier?
    let hkCategory: HKCategoryTypeIdentifier?

    static let phaseA: [HealthMetric] = [
        HealthMetric(
            id: "sleep",
            label: "Sleep",
            icon: "bed.double.fill",
            unit: "h",
            tier: .coreVitals,
            aggregation: .sleepCategory,
            chart: .sleepStackedBar,
            hkQuantity: nil,
            hkCategory: .sleepAnalysis
        ),
        HealthMetric(
            id: "restingHR",
            label: "Resting Heart Rate",
            icon: "heart.fill",
            unit: "BPM",
            tier: .coreVitals,
            aggregation: .average,
            chart: .line,
            hkQuantity: .restingHeartRate,
            hkCategory: nil
        ),
        HealthMetric(
            id: "steps",
            label: "Steps",
            icon: "figure.walk",
            unit: "steps",
            tier: .coreVitals,
            aggregation: .sum,
            chart: .bar,
            hkQuantity: .stepCount,
            hkCategory: nil
        ),
        HealthMetric(
            id: "weight",
            label: "Weight",
            icon: "scalemass.fill",
            // Display unit — the WeightCard view reformats per UserProfile.unitSystem.
            unit: "lb",
            tier: .coreVitals,
            aggregation: .latest,
            chart: .weightLine,
            hkQuantity: .bodyMass,
            hkCategory: nil
        ),
    ]

    // Used by the dashboard to scope queries to currently-shipping metrics
    // without committing to the full Phase B/C catalog yet.
    static let all: [HealthMetric] = phaseA
}
