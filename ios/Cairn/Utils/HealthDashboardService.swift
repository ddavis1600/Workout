import Foundation
import HealthKit
import Observation

// One sample point in a metric's time series. For most metrics `value`
// is the per-day aggregate (sum or average) and `secondary`/`stages`
// are nil. Sleep uses `stages` for per-stage breakdown; blood pressure
// uses `secondary` for the diastolic value (systolic in `value`).
struct MetricSample: Hashable, Identifiable {
    let id: UUID
    let date: Date
    let value: Double
    /// Companion value for paired metrics. Only set for blood pressure
    /// today (diastolic) — extra correlations may reuse this slot.
    let secondary: Double?
    let stages: SleepStages?

    init(date: Date, value: Double, secondary: Double? = nil, stages: SleepStages? = nil) {
        self.id = UUID()
        self.date = date
        self.value = value
        self.secondary = secondary
        self.stages = stages
    }
}

struct SleepStages: Hashable {
    let core: TimeInterval
    let deep: TimeInterval
    let rem: TimeInterval
    let unspecified: TimeInterval

    var totalSeconds: TimeInterval {
        core + deep + rem + unspecified
    }

    var totalHours: Double {
        totalSeconds / 3600.0
    }
}

// What the dashboard renders per metric: most-recent reading + the
// recent series for sparkline / chart. Views never query HK directly;
// they read a `MetricSummary` off the service.
struct MetricSummary: Hashable, Identifiable {
    let metric: HealthMetric
    let latest: MetricSample?
    let series: [MetricSample]

    var id: String { metric.id }
    var hasData: Bool { latest != nil }
}

@MainActor
@Observable
final class HealthDashboardService {
    static let shared = HealthDashboardService()

    private(set) var summaries: [String: MetricSummary] = [:]
    private(set) var isLoading: Bool = false
    private(set) var lastRefreshedAt: Date?

    // Mirrors the HR auth-gate pattern from P3 (HeartRateView.swift:564).
    // Read-type HK auth status is unreliable (always reports
    // .sharingDenied), so we anchor on workoutType (a write type whose
    // status flips on user decision) plus this UserDefaults flag to
    // avoid re-prompting on every dashboard appear.
    static let authStorageKey = "hasRequestedDashboardAuth"

    private let cacheTTL: TimeInterval = 300  // 5 min

    private init() {}

    // MARK: Auth

    /// One-shot batched auth ask. Phase A relies on the existing
    /// `HealthKitManager.requestAuthorization()` set, which already
    /// covers sleep / restingHeartRate / stepCount / bodyMass. Phase B
    /// expands `HealthKitManager.allReadTypes` to cover HRV / blood
    /// pressure / SpO2 / respiratory rate / body temp / VO2 max /
    /// active energy / exercise / stand hour, and bumps the auth
    /// bundle version so existing users get a one-shot re-prompt.
    func requestAuthorizationIfNeeded() async {
        guard HealthKitManager.shared.isAvailable else { return }

        let hasAskedBefore = UserDefaults.standard.bool(forKey: Self.authStorageKey)
        let workoutStatus = HealthKitManager.shared.healthStore
            .authorizationStatus(for: HKWorkoutType.workoutType())

        if !hasAskedBefore || workoutStatus == .notDetermined {
            _ = await HealthKitManager.shared.requestAuthorization()
            UserDefaults.standard.set(true, forKey: Self.authStorageKey)
        }
    }

    /// Whether we've ever asked for dashboard HK auth. Drives the
    /// first-launch handshake card (shown only when this is false AND
    /// no metric currently has data).
    var hasRequestedAuth: Bool {
        UserDefaults.standard.bool(forKey: Self.authStorageKey)
    }

    // MARK: Refresh

    /// Refresh only if the cache TTL has elapsed since the last successful
    /// fetch. Cheap to call on every screen-appear.
    func refreshIfStale() async {
        if let last = lastRefreshedAt, Date().timeIntervalSince(last) < cacheTTL {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard HealthKitManager.shared.isAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        let metrics = HealthMetric.all

        // Fan out HK queries in parallel. The `nonisolated static`
        // helpers below run off the main actor, so all queries
        // genuinely overlap rather than serializing through MainActor.
        let pairs = await withTaskGroup(of: (String, MetricSummary).self) { group in
            for metric in metrics {
                group.addTask {
                    let summary = await Self.fetchSummary(for: metric)
                    return (metric.id, summary)
                }
            }
            var dict: [String: MetricSummary] = [:]
            for await (id, summary) in group {
                dict[id] = summary
            }
            return dict
        }

        summaries = pairs
        lastRefreshedAt = Date()
    }

    /// Force-refresh a single metric over a custom window. Used by
    /// `MetricDetailSheet` when the user changes the time-range
    /// picker — the regular refresh() pulls each metric's catalog
    /// `windowDays`, but the detail sheet wants 1D/7D/30D/90D/1Y.
    func fetchSeries(for metric: HealthMetric, days: Int) async -> [MetricSample] {
        await Self.fetchSummary(for: metric, overrideDays: days).series
    }

    // MARK: Per-metric fetch (off-main)

    private nonisolated static func fetchSummary(
        for metric: HealthMetric,
        overrideDays: Int? = nil
    ) async -> MetricSummary {
        let days = overrideDays ?? metric.windowDays
        switch metric.aggregation {
        case .sum:                  return await fetchDailySumSummary(for: metric, days: days)
        case .average:              return await fetchDailyAverageSummary(for: metric, days: days)
        case .latest:               return await fetchLatestSummary(for: metric, days: days)
        case .sleepCategory:        return await fetchSleepSummary(for: metric)
        case .bloodPressure:        return await fetchBloodPressureSummary(for: metric, days: days)
        case .standHourCategory:    return await fetchStandHourSummary(for: metric, days: days)
        }
    }

    private nonisolated static func hkUnit(for qid: HKQuantityTypeIdentifier) -> HKUnit {
        switch qid {
        case .stepCount:                    return .count()
        case .restingHeartRate:             return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:     return .secondUnit(with: .milli)
        case .bodyMass:                     return .gramUnit(with: .kilo)
        case .oxygenSaturation:             return .percent()
        case .respiratoryRate:              return HKUnit.count().unitDivided(by: .minute())
        case .bodyTemperature:              return .degreeCelsius()
        case .vo2Max:
            // mL/(kg·min) — Apple's canonical VO2 max unit.
            return HKUnit(from: "ml/kg*min")
        case .activeEnergyBurned:           return .kilocalorie()
        case .appleExerciseTime:            return .minute()
        case .bloodPressureSystolic,
             .bloodPressureDiastolic:       return .millimeterOfMercury()
        default:                            return .count()
        }
    }

    private nonisolated static func empty(_ metric: HealthMetric) -> MetricSummary {
        MetricSummary(metric: metric, latest: nil, series: [])
    }

    // MARK: Daily-sum (steps, active energy, exercise minutes)

    private nonisolated static func fetchDailySumSummary(
        for metric: HealthMetric,
        days: Int
    ) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        let cal = Calendar.current
        let end = cal.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: cal.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: empty(metric))
                    return
                }
                var samples: [MetricSample] = []
                results.enumerateStatistics(from: start, to: end) { stats, _ in
                    let v = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    samples.append(MetricSample(date: stats.startDate, value: v))
                }
                let latest = samples.last(where: { $0.value > 0 }) ?? samples.last
                continuation.resume(returning: MetricSummary(metric: metric, latest: latest, series: samples))
            }
            HealthKitManager.shared.healthStore.execute(query)
        }
    }

    // MARK: Daily-average (resting HR, HRV, respiratory rate, SpO2, body temp)

    private nonisolated static func fetchDailyAverageSummary(
        for metric: HealthMetric,
        days: Int
    ) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        let cal = Calendar.current
        let end = cal.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: cal.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: empty(metric))
                    return
                }
                var samples: [MetricSample] = []
                results.enumerateStatistics(from: start, to: end) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    samples.append(MetricSample(date: stats.startDate, value: avg.doubleValue(for: unit)))
                }
                continuation.resume(returning: MetricSummary(metric: metric, latest: samples.last, series: samples))
            }
            HealthKitManager.shared.healthStore.execute(query)
        }
    }

    // MARK: Latest (weight, VO2 max)

    private nonisolated static func fetchLatestSummary(
        for metric: HealthMetric,
        days: Int
    ) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let results = try await descriptor.result(for: HealthKitManager.shared.healthStore)
            let samples = results.map { sample in
                MetricSample(date: sample.startDate, value: sample.quantity.doubleValue(for: unit))
            }
            return MetricSummary(metric: metric, latest: samples.last, series: samples)
        } catch {
            return empty(metric)
        }
    }

    // MARK: Sleep (custom)

    private nonisolated static func fetchSleepSummary(for metric: HealthMetric) async -> MetricSummary {
        guard let cid = metric.hkCategory,
              let sleepType = HKObjectType.categoryType(forIdentifier: cid) else {
            return empty(metric)
        }

        // 8-day window: yesterday's sleep can end after midnight, so we
        // pull a slightly-wider window than the 7 nights we render.
        let cal = Calendar.current
        let now = Date()
        let lastNight = cal.startOfDay(for: now)
        let queryStart = cal.date(byAdding: .day, value: -8, to: lastNight) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .forward)]
        )

        let samples: [HKCategorySample]
        do {
            samples = try await descriptor.result(for: HealthKitManager.shared.healthStore)
        } catch {
            return empty(metric)
        }

        // Bucket samples by the calendar day of their END date — that's
        // the morning the user "woke up on". Each night accumulates per
        // sleep stage so the stacked bar chart can render core/deep/REM.
        var byNight: [Date: (core: TimeInterval, deep: TimeInterval, rem: TimeInterval, unspec: TimeInterval)] = [:]

        for sample in samples {
            let nightKey = cal.startOfDay(for: sample.endDate)
            let dur = sample.endDate.timeIntervalSince(sample.startDate)
            let v = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            var entry = byNight[nightKey] ?? (0, 0, 0, 0)
            switch v {
            case .asleepCore:        entry.core   += dur
            case .asleepDeep:        entry.deep   += dur
            case .asleepREM:         entry.rem    += dur
            case .asleepUnspecified: entry.unspec += dur
            default:                 break  // .awake, .inBed: ignored
            }
            byNight[nightKey] = entry
        }

        // Render last 7 nights (today + 6 previous mornings). Empty
        // nights still appear so the chart x-axis stays continuous; the
        // dashboard's hide-on-no-data rule is enforced higher up off
        // `latest`, not series length.
        var series: [MetricSample] = []
        for offset in (0..<7).reversed() {
            guard let nightKey = cal.date(byAdding: .day, value: -offset, to: lastNight) else { continue }
            let entry = byNight[nightKey] ?? (0, 0, 0, 0)
            let stages = SleepStages(
                core: entry.core,
                deep: entry.deep,
                rem: entry.rem,
                unspecified: entry.unspec
            )
            series.append(MetricSample(date: nightKey, value: stages.totalHours, stages: stages))
        }

        let latest = series.last(where: { ($0.stages?.totalSeconds ?? 0) > 0 })
        return MetricSummary(metric: metric, latest: latest, series: series)
    }

    // MARK: Blood pressure (custom — paired correlation)

    /// Fetches blood-pressure correlations and projects them into the
    /// MetricSample shape the dashboard renders. Each sample's
    /// `value` carries systolic and `secondary` carries diastolic, in
    /// mmHg. The `latest` field exposes the most-recent paired
    /// reading for the on-card big-value pair (e.g. "118 / 76").
    private nonisolated static func fetchBloodPressureSummary(
        for metric: HealthMetric,
        days: Int
    ) async -> MetricSummary {
        guard let correlationType = HKObjectType.correlationType(forIdentifier: .bloodPressure) else {
            return empty(metric)
        }
        let systolicType  = HKQuantityType(.bloodPressureSystolic)
        let diastolicType = HKQuantityType(.bloodPressureDiastolic)
        let unit = HKUnit.millimeterOfMercury()

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: correlationType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                guard let correlations = results as? [HKCorrelation] else {
                    continuation.resume(returning: empty(metric))
                    return
                }
                let samples: [MetricSample] = correlations.compactMap { c in
                    guard
                        let sys = (c.objects(for: systolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit),
                        let dia = (c.objects(for: diastolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                    else { return nil }
                    return MetricSample(date: c.startDate, value: sys, secondary: dia)
                }
                continuation.resume(returning: MetricSummary(metric: metric, latest: samples.last, series: samples))
            }
            HealthKitManager.shared.healthStore.execute(query)
        }
    }

    // MARK: Stand hours (category — count `.stood` per day)

    /// Stand hours can't use `HKStatisticsCollectionQuery` directly
    /// (that's quantity-only). We fetch raw category samples and bucket
    /// them per day, counting only those with value `.stood`. Each
    /// MetricSample's `value` is the per-day count (0…24).
    private nonisolated static func fetchStandHourSummary(
        for metric: HealthMetric,
        days: Int
    ) async -> MetricSummary {
        guard
            let cid = metric.hkCategory,
            let standType = HKObjectType.categoryType(forIdentifier: cid)
        else { return empty(metric) }

        let cal = Calendar.current
        let end = cal.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: standType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples: [HKCategorySample]
        do {
            samples = try await descriptor.result(for: HealthKitManager.shared.healthStore)
        } catch {
            return empty(metric)
        }

        var counts: [Date: Int] = [:]
        for sample in samples {
            guard sample.value == HKCategoryValueAppleStandHour.stood.rawValue else { continue }
            let key = cal.startOfDay(for: sample.startDate)
            counts[key, default: 0] += 1
        }

        var series: [MetricSample] = []
        for offset in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let count = counts[day] ?? 0
            series.append(MetricSample(date: day, value: Double(count)))
        }
        let latest = series.last(where: { $0.value > 0 }) ?? series.last
        return MetricSummary(metric: metric, latest: latest, series: series)
    }
}
