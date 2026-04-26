import HealthKit
import SwiftData
import Combine

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - HealthKit type sets
    //
    // These are the COMPLETE sets of every type the iPhone + Watch combined
    // ever read from or write to HealthKit. `requestAuthorization()` always
    // asks for this full superset so iOS shows the HK permission sheet at
    // most once per install — any subsequent call is a silent no-op because
    // every tuple (type, read|write) has already been decided.
    //
    // Previously different code paths (HeartRateView, WorkoutPersistence,
    // WatchWorkoutSession, WatchHeartRateService) each asked for their own
    // distinct subset. Every new subset introduced a still-undecided tuple,
    // which triggered a fresh sheet. Result: user kept getting the
    // "Cairn would like to access Health data" prompt on every new
    // action until every subset had been covered.

    /// Every HK type the app might ever WRITE. Keep this in sync with the
    /// watch-side request in `WatchWorkoutSession.start()` so first prompt
    /// covers both surfaces.
    ///
    /// V2 of this bundle (P6 — F9) added `bodyFatPercentage` and
    /// `mindfulSession`. Bumping `currentAuthBundleVersion` below
    /// triggers a one-shot re-auth via `requestAuthorizationIfNeeded()`
    /// for users who previously granted V1.
    static var allShareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),       // F9 — body composition
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryFiber),
        ]
        // F9 — mindful sessions; future-proofs for a meditation
        // feature so the V2 auth bundle covers mindful writes and we
        // don't have to re-prompt when the UI lands.
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        return types
    }

    /// Every HK type the app might ever READ.
    ///
    /// Resolution strategy: pre-V3 types use the non-failable
    /// `HKQuantityType(_:)` initializer (added iOS 15.4) since
    /// they shipped in Phase A without issues. V3 (Phase B) types
    /// resolve through the failable
    /// `HKObjectType.quantityType(forIdentifier:)` API + compactMap
    /// instead.
    ///
    /// Why the change: build 36 introduced a hard crash at the
    /// auth-flow handshake on Daniel's device. Apple documents the
    /// non-failable initializer as "a convenience initializer for
    /// non-deprecated identifiers" — it asserts (unrecoverable
    /// crash) on any identifier the running OS can't resolve. The
    /// failable form returns nil instead, which the compactMap
    /// then drops, so a transient mismatch downgrades to "the
    /// dashboard quietly misses one card" rather than "the app
    /// terminates before the auth sheet renders". This also
    /// matches the pattern already used for category and
    /// correlation types below.
    static var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
        ]
        // V3 — Phase B Health Dashboard quantity reads. Failable
        // resolution per the doc-comment above.
        let v3QuantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .oxygenSaturation,
            .respiratoryRate,
            .bodyTemperature,
            .vo2Max,
        ]
        types.formUnion(
            v3QuantityIDs.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
        )

        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        // V3 — stand hour category for the Tier 2 Stand card.
        if let standHour = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            types.insert(standHour)
        }
        // ⚠️ DO NOT add HKCorrelationType to this set.
        //
        // V3 originally registered the blood-pressure correlation
        // here "for visibility in the Privacy sheet". On Daniel's
        // device that triggered an unrecoverable
        // `_throwIfAuthorizationDisallowedForSharing` NSException
        // at the auth-handshake — the same crash class documented
        // in the Food Diary comment below (~line 608): correlation
        // types in the auth set raise an uncatchable Objective-C
        // exception that bypasses Swift's `try`/`catch` and tears
        // the process down before the permission sheet renders.
        //
        // The two component types (`bloodPressureSystolic` /
        // `bloodPressureDiastolic`) registered above are sufficient
        // — `HKSampleQuery(sampleType: bpCorrelation, …)` works as
        // long as the components are authorised. The correlation
        // type itself never needs to appear in the auth set.
        return types
    }

    /// Current HK auth bundle version. Bump when adding new types so
    /// existing users get prompted once for the expanded set.
    /// V2 added bodyFatPercentage + mindfulSession.
    /// V3 (Phase B Health Dashboard) added HRV, blood pressure
    /// correlation + components, oxygen saturation, respiratory
    /// rate, body temperature, VO2 max, stand hour.
    private static let currentAuthBundleVersion = 3

    private static let authBundleVersionKey = "hasRequestedHKBundleVersion"

    /// Force a fresh HealthKit prompt regardless of stored version.
    /// Used by settings-style affordances ("Re-request Health access").
    /// Pins the version key on success so subsequent
    /// `requestAuthorizationIfNeeded()` calls stay silent.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let shareTypes = Self.allShareTypes
        let readTypes  = Self.allReadTypes
        // Diagnostic — sorted identifier list goes to the device
        // console so that if the auth handshake ever crashes again
        // (the kind of uncatchable Objective-C NSException that
        // build 36 hit) the last log line names every type that was
        // about to be requested. Cheap; runs at most once per
        // bundle-version bump per install.
        print("[HK] auth bundle V\(Self.currentAuthBundleVersion) — share=\(shareTypes.count), read=\(readTypes.count)")
        print("[HK]   share: \(shareTypes.map { $0.identifier }.sorted())")
        print("[HK]   read:  \(readTypes.map { $0.identifier }.sorted())")
        do {
            try await healthStore.requestAuthorization(
                toShare: shareTypes,
                read:    readTypes
            )
            UserDefaults.standard.set(Self.currentAuthBundleVersion, forKey: Self.authBundleVersionKey)
            return true
        } catch {
            print("HealthKit auth failed: \(error)")
            return false
        }
    }

    /// Idempotent variant — only prompts when the user hasn't yet been
    /// asked for the current bundle version. Once granted (or denied)
    /// at the latest version, subsequent calls return immediately.
    /// New F9 call sites (BodyMeasurements body-fat write, Diary
    /// hydration +1 cup) use this for the silent re-use path.
    func requestAuthorizationIfNeeded() async -> Bool {
        guard isAvailable else { return false }
        let storedVersion = UserDefaults.standard.integer(forKey: Self.authBundleVersionKey)
        if storedVersion >= Self.currentAuthBundleVersion {
            return true
        }
        return await requestAuthorization()
    }

    // MARK: - Workout

    /// Maps the stored `Workout.workoutType` string (from the in-app picker)
    /// to an HKWorkoutActivityType for Apple Health. Unknown / nil values
    /// fall back to `.traditionalStrengthTraining` so legacy workouts saved
    /// before the type picker was added still report as strength training.
    static func hkActivityType(from stored: String?) -> HKWorkoutActivityType {
        switch stored {
        case "running":   return .running
        case "cycling":   return .cycling
        case "walking":   return .walking
        case "hiit":      return .highIntensityIntervalTraining
        case "yoga":      return .yoga
        case "swimming":  return .swimming
        case "other":     return .other
        default:          return .traditionalStrengthTraining
        }
    }

    /// HealthKit distance sample type that corresponds to an activity type.
    /// `nil` when the activity isn't distance-based (strength, yoga, hiit…).
    private static func distanceQuantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .running, .walking, .hiking:
            return HKQuantityType(.distanceWalkingRunning)
        case .cycling:
            return HKQuantityType(.distanceCycling)
        case .swimming:
            return HKQuantityType(.distanceSwimming)
        default:
            return nil
        }
    }

    /// Saves a completed workout to Apple Health / Fitness app.
    /// If `distanceMeters` is provided and the activity type supports it,
    /// also writes a paired HKQuantitySample so Apple Health shows the
    /// distance alongside the workout (and Fitness app computes pace).
    func saveWorkoutToHealth(
        startDate: Date,
        endDate: Date,
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
        distanceMeters: Double? = nil
    ) async {
        guard isAvailable else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        // Outdoor for distance activities so Apple Health classifies correctly
        // (matters for things like the Fitness app's auto-map view).
        config.locationType = Self.distanceQuantityType(for: activityType) != nil ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        // Build a distance sample up-front so we can add it inside the
        // collection window. Only runs when the activity type supports it
        // AND the caller actually passed a non-zero distance.
        var distanceSamples: [HKSample] = []
        if let meters = distanceMeters, meters > 0,
           let distanceType = Self.distanceQuantityType(for: activityType) {
            let quantity = HKQuantity(unit: .meter(), doubleValue: meters)
            let sample = HKQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: startDate,
                end: endDate
            )
            distanceSamples.append(sample)
        }

        await withCheckedContinuation { continuation in
            builder.beginCollection(withStart: startDate) { success, error in
                guard success else {
                    print("[HealthKit] beginCollection failed: \(String(describing: error))")
                    continuation.resume()
                    return
                }

                // Closure that ends the collection & finishes the workout.
                let finish = {
                    builder.endCollection(withEnd: endDate) { success, error in
                        guard success else {
                            print("[HealthKit] endCollection failed: \(String(describing: error))")
                            continuation.resume()
                            return
                        }
                        builder.finishWorkout { _, error in
                            if let error { print("[HealthKit] finishWorkout failed: \(error)") }
                            continuation.resume()
                        }
                    }
                }

                if distanceSamples.isEmpty {
                    finish()
                } else {
                    builder.add(distanceSamples) { success, error in
                        if let error { print("[HealthKit] add distance sample failed: \(error)") }
                        _ = success
                        finish()
                    }
                }
            }
        }

        // Invalidate workout-affected dashboard cards (steps,
        // active energy, exercise minutes, energy balance). The
        // continuation above settles when the workout has been
        // committed to HK; running invalidate after it ensures
        // the refetched cache reads the new data.
        await MainActor.run {
            HealthDashboardService.shared.invalidate(after: .workout)
        }
    }

    // MARK: - Weight

    func saveWeight(_ weightKg: Double, date: Date) async {
        guard isAvailable else { return }
        let weightType = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
            // Refresh the Weight dashboard card so the new entry
            // appears without waiting for the 5-min TTL.
            await MainActor.run {
                HealthDashboardService.shared.invalidate(after: .weight)
            }
        } catch {
            print("Failed to save weight to HealthKit: \(error)")
        }
    }

    func fetchWeights(from startDate: Date, to endDate: Date) async -> [(date: Date, weight: Double)] {
        guard isAvailable else { return [] }
        let weightType = HKQuantityType(.bodyMass)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            return results.map { sample in
                (date: sample.startDate, weight: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
        } catch {
            print("Failed to fetch weights from HealthKit: \(error)")
            return []
        }
    }

    // MARK: - Body Fat (F9)

    /// Save a body-fat percentage sample to Health. `percent` is the
    /// raw percentage (e.g. `18.5` for 18.5%); HealthKit stores it as a
    /// 0…1 fraction internally so we divide by 100 here.
    func saveBodyFatPercentage(_ percent: Double, date: Date) async {
        guard isAvailable else { return }
        // HK accepts values in [0, 1]. 0 is meaningless; clamp anything
        // above 100% as well — body-fat readings outside that range are
        // operator error.
        let clamped = max(0, min(percent, 100)) / 100.0
        guard clamped > 0 else { return }
        let type = HKQuantityType(.bodyFatPercentage)
        let quantity = HKQuantity(unit: .percent(), doubleValue: clamped)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
        } catch {
            print("Failed to save body fat to HealthKit: \(error)")
        }
    }

    // MARK: - Mindful Session (F9 — future-proofing)

    /// Save a mindful session of `minutes` minutes ending at `date`.
    /// Currently unused by the UI — the API is wired so the V2 auth
    /// bundle covers mindful writes and a future meditation feature
    /// can call this without triggering another permission prompt.
    func saveMindfulSession(minutes: Double, endDate: Date = .now) async {
        guard isAvailable, minutes > 0 else { return }
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let start = endDate.addingTimeInterval(-(minutes * 60))
        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: endDate
        )
        do {
            try await healthStore.save(sample)
            await MainActor.run {
                HealthDashboardService.shared.invalidate(after: .mindful)
            }
        } catch {
            print("Failed to save mindful session to HealthKit: \(error)")
        }
    }

    // MARK: - Water

    func saveWater(ml: Double, date: Date) async {
        guard isAvailable else { return }
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
            await MainActor.run {
                HealthDashboardService.shared.invalidate(after: .water)
            }
        } catch {
            print("Failed to save water to HealthKit: \(error)")
        }
    }

    func deleteLatestWater(date: Date) async {
        guard isAvailable else { return }
        let waterType = HKQuantityType(.dietaryWater)
        let start = date.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: waterType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            let samples = try await descriptor.result(for: healthStore)
            guard let latest = samples.first else { return }
            try await healthStore.delete(latest)
        } catch {
            print("Failed to delete water from HealthKit: \(error)")
        }
    }

    func fetchWaterToday() async -> Double {
        return await fetchDailySumQuantity(
            typeIdentifier: .dietaryWater,
            unit: .literUnit(with: .milli),
            date: Date()
        )
    }

    // MARK: - Heart Rate Stats

    func fetchRestingHeartRateStats(from start: Date, to end: Date) async -> (avg: Int, min: Int, max: Int)? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            let bpms = results.map { Int($0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))) }
            guard !bpms.isEmpty else { return nil }
            let avg = bpms.reduce(0, +) / bpms.count
            return (avg: avg, min: bpms.min()!, max: bpms.max()!)
        } catch {
            return nil
        }
    }

    func fetchHeartRateSamples(from start: Date, to end: Date) async -> [(Date, Int)] {
        guard isAvailable else { return [] }
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            return results.map { ($0.startDate, Int($0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))) }
        } catch {
            return []
        }
    }

    // MARK: - HealthKit Habit Trigger Fetch

    /// Returns the accumulated daily value for a given habit trigger identifier.
    /// Trigger identifiers match `HKHabitTrigger.identifier`.
    func fetchDailyValue(for trigger: String, on date: Date) async -> Double {
        guard isAvailable else { return 0 }
        switch trigger {
        case "stepCount":
            return await fetchDailySumQuantity(typeIdentifier: .stepCount, unit: .count(), date: date)
        case "activeEnergyBurned":
            return await fetchDailySumQuantity(typeIdentifier: .activeEnergyBurned, unit: .kilocalorie(), date: date)
        case "appleExerciseTime":
            return await fetchDailySumQuantity(typeIdentifier: .appleExerciseTime, unit: .minute(), date: date)
        case "workoutSessions":
            return await fetchWorkoutCount(on: date)
        case "mindfulSession":
            return await fetchMindfulMinutes(on: date)
        case "dietaryWater":
            return await fetchDailySumQuantity(typeIdentifier: .dietaryWater, unit: .literUnit(with: .milli), date: date)
        case "sleepDuration":
            return await fetchSleepHours(on: date)
        case "bodyMass":
            return await fetchLatestBodyMass(on: date)
        case "dietaryProtein":
            return await fetchDailySumQuantity(typeIdentifier: .dietaryProtein, unit: .gram(), date: date)
        case "dietaryCarbohydrates":
            return await fetchDailySumQuantity(typeIdentifier: .dietaryCarbohydrates, unit: .gram(), date: date)
        case "dietaryFatTotal":
            return await fetchDailySumQuantity(typeIdentifier: .dietaryFatTotal, unit: .gram(), date: date)
        case "zoneTwoMinutes":
            return await fetchZone2Minutes(on: date)
        default:
            return 0
        }
    }

    /// Daily total minutes spent in heart-rate Zone 2 (60–70% of max HR).
    /// Uses the same zone-classification helper as HeartRateService so
    /// in-workout and all-day math stay consistent. Max HR is derived from
    /// `heartRateUserAge` UserDefaults (220 − age), falling back to 180 if
    /// the user hasn't set their age yet.
    func fetchZone2Minutes(on date: Date) async -> Double {
        let start = date.startOfDay
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let samples = await fetchHeartRateSamples(from: start, to: end)
        guard samples.count >= 2 else { return 0 }

        let age = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        let maxHR = age > 0 ? (220 - age) : 180

        var totalSeconds: Double = 0
        for i in 0..<(samples.count - 1) {
            let (t1, bpm) = samples[i]
            let (t2, _)   = samples[i + 1]
            // Cap to 60s so gaps (watch off, sleep) don't inflate the total.
            let interval = min(t2.timeIntervalSince(t1), 60.0)
            if HeartRateZone.zone(for: bpm, maxHR: maxHR).number == 2 {
                totalSeconds += interval
            }
        }
        // Attribute ~30s for the trailing sample.
        if let last = samples.last,
           HeartRateZone.zone(for: last.1, maxHR: maxHR).number == 2 {
            totalSeconds += 30.0
        }

        return totalSeconds / 60.0
    }

    // MARK: - Private Helpers

    private func fetchDailySumQuantity(typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
        let quantityType = HKQuantityType(typeIdentifier)
        let start = date.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkoutCount(on date: Date) async -> Double {
        let start = date.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            return Double(results.count)
        } catch {
            return 0
        }
    }

    private func fetchMindfulMinutes(on date: Date) async -> Double {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let start = date.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: mindfulType, predicate: predicate)],
            sortDescriptors: []
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            let totalSeconds = results.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            return totalSeconds / 60.0
        } catch {
            return 0
        }
    }

    private func fetchSleepHours(on date: Date) async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        // Sleep for "date" typically means the night ending on that morning
        let end = date.startOfDay
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: []
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            let asleepSeconds = results
                .filter { sample in
                    let v = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    if #available(iOS 16, *) {
                        return v == .asleepUnspecified || v == .asleepCore || v == .asleepDeep || v == .asleepREM
                    } else {
                        return v == .asleep
                    }
                }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            return asleepSeconds / 3600.0
        } catch {
            return 0
        }
    }

    private func fetchLatestBodyMass(on date: Date) async -> Double {
        let weightType = HKQuantityType(.bodyMass)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: date.startOfDay) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            guard let sample = results.first else { return 0 }
            return sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        } catch {
            return 0
        }
    }

    // MARK: - Food Diary
    //
    // Food entries used to be saved as HKCorrelation(.food) wrapping the
    // five macro HKQuantitySamples. That hit an unrecoverable iOS auth
    // edge case for any user whose grant predated the food correlation
    // type — iOS would leave `.food` at `.notDetermined` and the
    // delete-by-correlation query crashed with an uncatchable
    // NSInvalidArgumentException ("Authorization to read … is
    // disallowed: HKCorrelationTypeIdentifierFood"). After multiple
    // failed bundle-version re-auth attempts we concluded there's no
    // way to recover the type once iOS has decided about a constituent.
    //
    // The fix is to never touch HKCorrelationType. Save individual
    // quantity samples tagged with `kFitTrackDiaryEntryIDKey` metadata.
    // Delete by querying each macro type with a metadata predicate.
    // Apple Health no longer groups the macros as a single "meal" entry
    // but still totals them correctly for the day; users see five
    // separate dietary-energy / protein / carb / fat / fiber samples
    // at the same timestamp.

    /// Metadata key the macro samples carry so `deleteFoodEntry` can
    /// find them later. Stored as the diary entry's UUID string.
    private static let kFitTrackDiaryEntryIDKey = "FitTrackDiaryEntryID"

    /// HealthKit-backed quantity types we save for a food diary entry.
    /// Used by both save and delete paths so they stay in sync.
    private static let foodMacroTypes: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
        .dietaryFiber,
    ]

    /// Saves a food diary entry as a set of individual `HKQuantitySample`s,
    /// one per non-zero macro. Returns a stable UUID the caller persists
    /// on `DiaryEntry.healthKitCorrelationID` (field name is now a
    /// historical misnomer — kept to avoid a model migration; the value
    /// is no longer a correlation UUID, just our own per-entry key).
    @discardableResult
    func saveFoodEntry(
        date: Date,
        mealType: String,
        foodName: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double
    ) async -> UUID? {
        guard isAvailable else { return nil }

        let entryID = UUID()
        let metadata: [String: Any] = [
            Self.kFitTrackDiaryEntryIDKey: entryID.uuidString,
            HKMetadataKeyFoodType: foodName,
            "HKMealSlot": mealType,
        ]

        let values: [(HKQuantityTypeIdentifier, HKUnit, Double)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), calories),
            (.dietaryProtein,        .gram(),         protein),
            (.dietaryCarbohydrates,  .gram(),         carbs),
            (.dietaryFatTotal,       .gram(),         fat),
            (.dietaryFiber,          .gram(),         fiber),
        ]
        var samples: [HKQuantitySample] = []
        for (identifier, unit, value) in values where value > 0 {
            let qty = HKQuantity(unit: unit, doubleValue: value)
            samples.append(
                HKQuantitySample(
                    type: HKQuantityType(identifier),
                    quantity: qty,
                    start: date,
                    end: date,
                    metadata: metadata
                )
            )
        }
        guard !samples.isEmpty else { return nil }

        do {
            try await healthStore.save(samples)
            await MainActor.run {
                HealthDashboardService.shared.invalidate(after: .food)
            }
            return entryID
        } catch {
            print("[HealthKit] Failed to save food samples: \(error)")
            return nil
        }
    }

    func updateFoodEntry(
        existingCorrelationID: UUID?,
        date: Date,
        mealType: String,
        foodName: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double
    ) async -> UUID? {
        if let id = existingCorrelationID { await deleteFoodEntry(correlationID: id) }
        return await saveFoodEntry(
            date: date, mealType: mealType, foodName: foodName,
            calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber
        )
    }

    /// Deletes the macro samples saved by `saveFoodEntry` for the given
    /// entry ID. **Never touches HKCorrelationType** — works entirely
    /// through quantity-sample queries gated by metadata.
    ///
    /// Backward-compat caveat: entries saved by the previous correlation-
    /// based version stored an actual HKCorrelation.uuid in
    /// `DiaryEntry.healthKitCorrelationID`. Those samples don't carry
    /// our metadata key, so this function silently no-ops on them and
    /// the orphaned correlation lingers in Apple Health. Acceptable
    /// trade — alternative is the app crashing every diary edit. Users
    /// can clean up legacy rows in the Health app.
    func deleteFoodEntry(correlationID: UUID) async {
        guard isAvailable else { return }

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: Self.kFitTrackDiaryEntryIDKey,
            operatorType: .equalTo,
            value: correlationID.uuidString
        )

        var allSamples: [HKQuantitySample] = []
        for identifier in Self.foodMacroTypes {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
                sortDescriptors: []
            )
            do {
                let results = try await descriptor.result(for: healthStore)
                allSamples.append(contentsOf: results)
            } catch {
                print("[HealthKit] Failed to query \(identifier) for delete: \(error)")
            }
        }
        guard !allSamples.isEmpty else { return }
        do {
            try await healthStore.delete(allSamples)
        } catch {
            print("[HealthKit] Failed to delete food samples: \(error)")
        }
    }
}

// MARK: - Habit Trigger Metadata

struct HKHabitTrigger: Identifiable, Hashable {
    let id: String       // matches the switch cases in fetchDailyValue
    let displayName: String
    let unit: String
    let defaultThreshold: Double
    let icon: String

    static let all: [HKHabitTrigger] = [
        HKHabitTrigger(id: "stepCount",              displayName: "Steps",                unit: "steps",   defaultThreshold: 10000, icon: "figure.walk"),
        HKHabitTrigger(id: "activeEnergyBurned",     displayName: "Active Energy",        unit: "kcal",    defaultThreshold: 500,   icon: "flame.fill"),
        HKHabitTrigger(id: "appleExerciseTime",      displayName: "Exercise Minutes",     unit: "min",     defaultThreshold: 30,    icon: "dumbbell.fill"),
        HKHabitTrigger(id: "workoutSessions",        displayName: "Workout Sessions",     unit: "sessions",defaultThreshold: 1,     icon: "sportscourt.fill"),
        HKHabitTrigger(id: "mindfulSession",         displayName: "Mindful Minutes",      unit: "min",     defaultThreshold: 10,    icon: "brain"),
        HKHabitTrigger(id: "dietaryWater",           displayName: "Water",                unit: "mL",      defaultThreshold: 2000,  icon: "drop.fill"),
        HKHabitTrigger(id: "sleepDuration",          displayName: "Sleep Duration",       unit: "hrs",     defaultThreshold: 7,     icon: "bed.double.fill"),
        HKHabitTrigger(id: "bodyMass",               displayName: "Body Weight Logged",   unit: "kg",      defaultThreshold: 0,     icon: "scalemass.fill"),
        HKHabitTrigger(id: "dietaryProtein",         displayName: "Dietary Protein",      unit: "g",       defaultThreshold: 100,   icon: "fork.knife"),
        HKHabitTrigger(id: "dietaryCarbohydrates",   displayName: "Dietary Carbs",        unit: "g",       defaultThreshold: 150,   icon: "leaf.fill"),
        HKHabitTrigger(id: "dietaryFatTotal",        displayName: "Dietary Fat",          unit: "g",       defaultThreshold: 50,    icon: "drop.circle.fill"),
        HKHabitTrigger(id: "zoneTwoMinutes",         displayName: "Zone 2 Cardio",        unit: "min",     defaultThreshold: 30,    icon: "heart.fill"),
    ]
}
