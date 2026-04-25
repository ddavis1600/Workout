import Foundation
import HealthKit
import Observation

// One sample point in a metric's time series. For most metrics `value`
// is the per-day aggregate (sum or average) and `stages` is nil. Sleep
// is the exception: `value` is total asleep hours and `stages` carries
// the per-stage breakdown the stacked bar chart consumes.
struct MetricSample: Hashable, Identifiable {
    let id: UUID
    let date: Date
    let value: Double
    let stages: SleepStages?

    init(date: Date, value: Double, stages: SleepStages? = nil) {
        self.id = UUID()
        self.date = date
        self.value = value
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
    /// covers sleep / restingHeartRate / stepCount / bodyMass — no
    /// expansion needed. Phase B will introduce a dashboard-specific
    /// overload when the metric set grows beyond what other features ask.
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
        // helpers below run off the main actor, so the four queries
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

    // MARK: Per-metric fetch (off-main)

    private nonisolated static func fetchSummary(for metric: HealthMetric) async -> MetricSummary {
        switch metric.aggregation {
        case .sum:            return await fetchDailySumSummary(for: metric)
        case .average:        return await fetchDailyAverageSummary(for: metric)
        case .latest:         return await fetchLatestSummary(for: metric)
        case .sleepCategory:  return await fetchSleepSummary(for: metric)
        }
    }

    private nonisolated static func hkUnit(for qid: HKQuantityTypeIdentifier) -> HKUnit {
        switch qid {
        case .stepCount:        return .count()
        case .restingHeartRate: return HKUnit.count().unitDivided(by: .minute())
        case .bodyMass:         return .gramUnit(with: .kilo)
        default:                return .count()
        }
    }

    private nonisolated static func empty(_ metric: HealthMetric) -> MetricSummary {
        MetricSummary(metric: metric, latest: nil, series: [])
    }

    private nonisolated static func fetchDailySumSummary(for metric: HealthMetric) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        let cal = Calendar.current
        let end = cal.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
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

    private nonisolated static func fetchDailyAverageSummary(for metric: HealthMetric) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        let cal = Calendar.current
        let end = cal.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
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

    private nonisolated static func fetchLatestSummary(for metric: HealthMetric) async -> MetricSummary {
        guard let qid = metric.hkQuantity else { return empty(metric) }
        let quantityType = HKQuantityType(qid)
        let unit = hkUnit(for: qid)

        // 30-day window so the weight chart has range without paging.
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -30, to: end) ?? end
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
}
