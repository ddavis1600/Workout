import Foundation
import HealthKit

// Static catalog describing each metric the Health Dashboard surfaces.
// Phase A shipped the four Core Vitals entries (sleep / restingHR /
// steps / weight). Phase B extends `phaseB` with five more Tier 1
// metrics + four Tier 2 (Fitness) metrics, behind the same data-driven
// rendering layer.
//
// The service layer dispatches HK queries off `aggregation`; the view
// layer dispatches chart rendering off `chart`. New aggregation /
// chart cases land alongside the metrics that use them.
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
    // for quantity types and a custom code path for sleep + correlations
    // + category counts.
    enum Aggregation: Hashable {
        case sum                    // cumulativeSum  — steps, energy
        case average                // discreteAverage — resting HR, HRV
        case latest                 // most-recent sample — weight, VO2 max
        case sleepCategory          // custom asleepCore/Deep/REM bucketing
        case bloodPressure          // HKCorrelationType: paired sys/dia
        case standHourCategory      // count of `.standHour` per day
    }

    enum Chart: Hashable {
        case sleepStackedBar    // per-night stages (last 7 nights)
        case line               // smoothed line — resting HR, HRV, RR
        case bar                // bars per day — steps, active energy
        case weightLine         // smoothed line, 30-day window
        case bloodPressureLines // dual line — systolic + diastolic
        case sparseDot          // sparse dots — body temperature
        case dotBand            // dots + threshold band — SpO2
        case barWithGoal        // bars per day + goal line — exercise / stand
        case sparkline          // tiny line behind a big number — VO2 max
    }

    let id: String
    let label: String
    let icon: String
    let unit: String
    let tier: Tier
    let aggregation: Aggregation
    let chart: Chart
    /// Number of trailing days the dashboard card should display.
    /// Phase A defaulted to 7d (sleep / steps / restingHR) and 30d
    /// (weight). Phase B varies more — 7d for SpO2 (sparse Watch
    /// samples), 30d for HRV / RR / activity, 90d for body temp /
    /// VO2 max. Detail sheet's range picker overrides this at view
    /// time; the catalog value drives the on-card sparkline window.
    let windowDays: Int
    /// Optional Apple Health deep-link path (the part after
    /// `x-apple-health://`). Detail sheet's "Open in Apple Health"
    /// button uses this. When nil, the button shows a generic
    /// fallback URL that lands on the Health app's Browse tab.
    let healthAppPath: String?
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
            windowDays: 7,
            healthAppPath: nil,
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
            windowDays: 7,
            healthAppPath: nil,
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
            windowDays: 7,
            healthAppPath: nil,
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
            windowDays: 30,
            healthAppPath: nil,
            hkQuantity: .bodyMass,
            hkCategory: nil
        ),
    ]

    /// Phase B catalog — populated incrementally across the per-metric
    /// commits. A metric appears in this array AND in `.all` when its
    /// commit lands.
    static let phaseB: [HealthMetric] = [
        // MARK: Tier 1 — Core Vitals (Phase B additions)

        HealthMetric(
            id: "hrv",
            label: "Heart Rate Variability",
            // SDNN — beat-to-beat variability in ms; the canonical
            // "stress / recovery" proxy on Apple Watch.
            icon: "waveform.path.ecg",
            unit: "ms",
            tier: .coreVitals,
            aggregation: .average,
            chart: .line,
            // 30-day window: HRV is noisy day-to-day, so the on-card
            // sparkline reads as a trend rather than a daily metric.
            windowDays: 30,
            healthAppPath: "Browse/Heart/Heart%20Rate%20Variability",
            hkQuantity: .heartRateVariabilitySDNN,
            hkCategory: nil
        ),
        HealthMetric(
            id: "bloodPressure",
            label: "Blood Pressure",
            icon: "heart.circle.fill",
            unit: "mmHg",
            tier: .coreVitals,
            // Custom correlation fetch — paired systolic + diastolic
            // (`value` / `secondary` on each MetricSample).
            aggregation: .bloodPressure,
            chart: .bloodPressureLines,
            // 30-day window matches HRV; BP is sampled occasionally
            // not daily, so we want to see a month of dots.
            windowDays: 30,
            healthAppPath: "Browse/Heart/Blood%20Pressure",
            // No single hkQuantity — the service uses the
            // .bloodPressure correlation type internally.
            hkQuantity: nil,
            hkCategory: nil
        ),
        HealthMetric(
            id: "spo2",
            label: "Blood Oxygen",
            icon: "lungs.fill",
            unit: "%",
            tier: .coreVitals,
            aggregation: .average,
            chart: .dotBand,
            // 7-day window: SpO2 is sampled sporadically (often only
            // overnight on newer Watches), so a short window keeps the
            // chart from looking empty between readings.
            windowDays: 7,
            healthAppPath: "Browse/Respiratory/Blood%20Oxygen",
            hkQuantity: .oxygenSaturation,
            hkCategory: nil
        ),
        HealthMetric(
            id: "respiratoryRate",
            label: "Respiratory Rate",
            icon: "wind",
            unit: "br/min",
            tier: .coreVitals,
            aggregation: .average,
            chart: .line,
            windowDays: 30,
            healthAppPath: "Browse/Respiratory/Respiratory%20Rate",
            hkQuantity: .respiratoryRate,
            hkCategory: nil
        ),
        HealthMetric(
            id: "bodyTemperature",
            label: "Body Temperature",
            icon: "thermometer.medium",
            // Display unit — MetricCard reformats based on
            // UserProfile.unitSystem (imperial → °F, metric → °C).
            unit: "°F",
            tier: .coreVitals,
            aggregation: .average,
            chart: .sparseDot,
            // 90-day window: body temp is sampled occasionally (basal
            // tracking, sick-day check, Watch overnight). Three months
            // gives a real chart even with sparse data.
            windowDays: 90,
            healthAppPath: "Browse/Body%20Measurements/Body%20Temperature",
            hkQuantity: .bodyTemperature,
            hkCategory: nil
        ),

        // MARK: Tier 2 — Fitness

        HealthMetric(
            id: "vo2Max",
            label: "VO2 Max",
            // Cardio capacity — Apple's "Cardio Fitness" metric.
            // Updated infrequently (one Watch outdoor walk/run per
            // week or so) so the on-card sparkline trails 90 days.
            icon: "lungs.fill",
            unit: "ml/kg·min",
            tier: .fitness,
            aggregation: .latest,
            chart: .sparkline,
            windowDays: 90,
            healthAppPath: "Browse/Heart/Cardio%20Fitness",
            hkQuantity: .vo2Max,
            hkCategory: nil
        ),
        HealthMetric(
            id: "activeEnergy",
            label: "Active Energy",
            icon: "flame.fill",
            unit: "kcal",
            tier: .fitness,
            aggregation: .sum,
            chart: .bar,
            windowDays: 30,
            healthAppPath: "Browse/Activity/Active%20Energy",
            hkQuantity: .activeEnergyBurned,
            hkCategory: nil
        ),
        HealthMetric(
            id: "exerciseMinutes",
            label: "Exercise",
            // Apple's Exercise ring metric — defaults to 30 min/day.
            icon: "figure.mixed.cardio",
            unit: "min",
            tier: .fitness,
            aggregation: .sum,
            chart: .barWithGoal,
            windowDays: 30,
            healthAppPath: "Browse/Activity/Exercise%20Minutes",
            hkQuantity: .appleExerciseTime,
            hkCategory: nil
        ),
        HealthMetric(
            id: "standHours",
            label: "Stand",
            // Apple's Stand ring — count of hours per day with
            // ≥1 minute of standing motion. Default goal is 12.
            icon: "figure.stand",
            unit: "hr",
            tier: .fitness,
            aggregation: .standHourCategory,
            chart: .barWithGoal,
            windowDays: 30,
            healthAppPath: "Browse/Activity/Stand%20Hours",
            hkQuantity: nil,
            hkCategory: .appleStandHour
        ),
    ]

    // Used by the dashboard to scope queries to currently-shipping metrics
    // without committing to the full Phase B/C catalog yet.
    static let all: [HealthMetric] = phaseA + phaseB
}
