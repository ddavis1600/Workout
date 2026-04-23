import Foundation
import HealthKit

// MARK: - Heart Rate Zone Model

struct HeartRateZone: Identifiable {
    let number: Int
    let name: String
    let description: String
    let minPercent: Double
    let maxPercent: Double
    let color: String // Color name to resolve in SwiftUI
    let minBPM: Int
    let maxBPM: Int

    var id: Int { number }

    static func allZones(maxHR: Int) -> [HeartRateZone] {
        [
            HeartRateZone(number: 1, name: "Warm Up", description: "Easy effort, recovery pace",
                         minPercent: 0.50, maxPercent: 0.60, color: "gray",
                         minBPM: Int(Double(maxHR) * 0.50), maxBPM: Int(Double(maxHR) * 0.60)),
            HeartRateZone(number: 2, name: "Fat Burn", description: "Light effort, conversational pace",
                         minPercent: 0.60, maxPercent: 0.70, color: "blue",
                         minBPM: Int(Double(maxHR) * 0.60), maxBPM: Int(Double(maxHR) * 0.70)),
            HeartRateZone(number: 3, name: "Cardio", description: "Moderate effort, steady state",
                         minPercent: 0.70, maxPercent: 0.80, color: "green",
                         minBPM: Int(Double(maxHR) * 0.70), maxBPM: Int(Double(maxHR) * 0.80)),
            HeartRateZone(number: 4, name: "Hard", description: "Hard effort, threshold training",
                         minPercent: 0.80, maxPercent: 0.90, color: "orange",
                         minBPM: Int(Double(maxHR) * 0.80), maxBPM: Int(Double(maxHR) * 0.90)),
            HeartRateZone(number: 5, name: "Max", description: "All-out effort, peak performance",
                         minPercent: 0.90, maxPercent: 1.00, color: "red",
                         minBPM: Int(Double(maxHR) * 0.90), maxBPM: maxHR),
        ]
    }

    static func zone(for bpm: Int, maxHR: Int) -> HeartRateZone {
        let zones = allZones(maxHR: maxHR)
        let percent = Double(bpm) / Double(maxHR)
        if percent >= 0.90 { return zones[4] }
        if percent >= 0.80 { return zones[3] }
        if percent >= 0.70 { return zones[2] }
        if percent >= 0.60 { return zones[1] }
        return zones[0]
    }
}

// MARK: - Heart Rate Service

@MainActor @Observable
final class HeartRateService {
    var currentBPM: Int = 0
    var lastUpdated: Date?
    var isMonitoring: Bool = false

    // Session tracking
    private(set) var sessionSamples: [(timestamp: Date, bpm: Int)] = []

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var refreshTimer: Timer?
    private let manager = HealthKitManager.shared

    // MARK: - Computed Session Stats

    var sessionMaxBPM: Int {
        sessionSamples.map(\.bpm).max() ?? 0
    }

    var sessionMinBPM: Int {
        sessionSamples.map(\.bpm).min() ?? 0
    }

    var sessionAvgBPM: Int {
        guard !sessionSamples.isEmpty else { return 0 }
        return sessionSamples.map(\.bpm).reduce(0, +) / sessionSamples.count
    }

    /// Calculate time spent in each zone (1–5) based on consecutive sample intervals
    func zoneDurations(maxHR: Int) -> [Int: TimeInterval] {
        var durations: [Int: TimeInterval] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        guard sessionSamples.count >= 2 else {
            // Single sample — attribute nothing yet
            return durations
        }

        for i in 0..<(sessionSamples.count - 1) {
            let sample = sessionSamples[i]
            let nextSample = sessionSamples[i + 1]
            let interval = nextSample.timestamp.timeIntervalSince(sample.timestamp)
            // Cap interval to 30 seconds to avoid counting long gaps (e.g. watch removed)
            let cappedInterval = min(interval, 30.0)
            let zone = HeartRateZone.zone(for: sample.bpm, maxHR: maxHR)
            durations[zone.number, default: 0] += cappedInterval
        }

        // Attribute the last sample too (assume it lasts ~5 seconds)
        if let last = sessionSamples.last {
            let zone = HeartRateZone.zone(for: last.bpm, maxHR: maxHR)
            durations[zone.number, default: 0] += 5.0
        }

        return durations
    }

    // MARK: - Session Management

    func resetSession() {
        sessionSamples = []
        currentBPM = 0
        lastUpdated = nil
    }

    // MARK: - Monitoring

    func startMonitoring() async {
        guard manager.isAvailable else { return }
        let authorized = await manager.requestAuthorization()
        guard authorized else { return }

        let heartRateType = HKQuantityType(.heartRate)

        // Fetch most recent sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let recentQuery = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            let date = sample.startDate
            Task { @MainActor [weak self] in
                self?.currentBPM = bpm
                self?.lastUpdated = date
                self?.sessionSamples.append((timestamp: date, bpm: bpm))
            }
        }
        manager.healthStore.execute(recentQuery)

        // Live monitoring
        let anchorQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleSamples(samples)
        }

        anchorQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleSamples(samples)
        }

        heartRateQuery = anchorQuery
        manager.healthStore.execute(anchorQuery)
        isMonitoring = true

        // Failsafe periodic refresh (item 4): the anchored query's
        // updateHandler only fires when new samples land in HealthKit.
        // When the Watch workout session ends or the watch is idle,
        // the handler can stay silent for minutes — so the on-screen
        // HR appears frozen even if fresh samples are actually available.
        // Re-run the "most recent sample" query every 5s to paper over that.
        startRefreshTimer()
    }

    func stopMonitoring() {
        if let query = heartRateQuery {
            manager.healthStore.stop(query)
            heartRateQuery = nil
        }
        stopRefreshTimer()
        isMonitoring = false
    }

    // MARK: - Periodic refresh (item 4)

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLatestSample()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Run a one-shot query for the most recent heart-rate sample in the last
    /// 60 seconds and update the display if newer than what's showing. Does
    /// NOT append to sessionSamples — the anchored query owns that stream —
    /// so zone-duration math stays accurate.
    private func refreshLatestSample() {
        guard manager.isAvailable else { return }
        let heartRateType = HKQuantityType(.heartRate)
        let since = Date().addingTimeInterval(-60)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            let date = sample.startDate
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Only overwrite if the sample is newer than what we have.
                if self.lastUpdated == nil || date > (self.lastUpdated ?? .distantPast) {
                    self.currentBPM = bpm
                    self.lastUpdated = date
                }
            }
        }
        manager.healthStore.execute(query)
    }

    // MARK: - Sample Processing

    nonisolated private func handleSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }

        let processed = heartRateSamples.map { sample in
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            return (timestamp: sample.startDate, bpm: bpm)
        }

        guard let mostRecent = processed.last else { return }

        Task { @MainActor [weak self] in
            self?.currentBPM = mostRecent.bpm
            self?.lastUpdated = mostRecent.timestamp
            self?.sessionSamples.append(contentsOf: processed)
        }
    }
}
