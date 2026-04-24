import HealthKit
import SwiftData
import Combine

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - All readable types

    private var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryWater),
            // Every macro that `saveFoodEntry` puts inside an
            // HKCorrelation(.food) also needs to appear in the READ
            // set. HealthKit's auth sheet treats a correlation as a
            // composite — if any of its constituent sample types is
            // missing from reads, iOS won't register the correlation
            // type at all. That's why Daniel's earlier v2 re-auth
            // left `.food` at `.notDetermined` and `deleteFoodEntry`
            // kept crashing with "Authorization to read … is
            // disallowed: HKCorrelationTypeIdentifierFood".
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryFiber),
            HKWorkoutType.workoutType(),
            HKCorrelationType(.food),
        ]
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        // HKCorrelationType is deliberately NOT in shareTypes. HealthKit
        // throws an uncaught NSInvalidArgumentException —
        //   "Authorization to share the following types is disallowed:
        //    HKCorrelationTypeIdentifierFood"
        // — the moment `requestAuthorization(toShare:read:)` sees a
        // correlation type in its share set. Apple only allows sharing
        // the underlying sample types; `saveFoodEntry` builds the
        // HKCorrelation from its contained HKQuantitySamples at write
        // time, which HealthKit accepts because each sample's type is
        // individually shareable. Reads are separately allowed and the
        // correlation type lives in `allReadTypes`.
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKWorkoutType.workoutType(),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryFiber),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: allReadTypes)
            return true
        } catch {
            print("HealthKit auth failed: \(error)")
            return false
        }
    }

    // MARK: - Bundle versioning (forced re-auth after read-set expansion)

    /// Bump this whenever a new type gets added to `allReadTypes` or
    /// `shareTypes` that wasn't present in a prior shipping build. iOS
    /// silently skips re-prompting for types it has already recorded a
    /// decision on, so without this mechanism an existing user's grant
    /// covers only the old types — a query against any newly added type
    /// throws `NSInvalidArgumentException("Authorization to read … is
    /// disallowed")` and crashes the app.
    ///
    /// Version log:
    ///   v1 — original bundle: bodyMass, heartRate (+resting), stepCount,
    ///        activeEnergyBurned, appleExerciseTime, dietaryWater,
    ///        workoutType, mindfulSession, sleepAnalysis.
    ///   v2 — adds dietaryProtein/Carbs/Fat reads + HKCorrelationType(.food)
    ///        + matching share types for food-diary writeback. **Was
    ///        broken in practice**: HealthKit treats a correlation as a
    ///        composite — every constituent sample type must be in the
    ///        read set or iOS silently drops the correlation from the
    ///        auth sheet. v2's read set was missing dietaryEnergyConsumed
    ///        and dietaryFiber (which `saveFoodEntry` packs into the
    ///        correlation), so the sheet never registered `.food` and
    ///        existing users kept crashing in `deleteFoodEntry`.
    ///   v3 — **current**: adds the missing dietaryEnergyConsumed and
    ///        dietaryFiber reads. With every constituent of the food
    ///        correlation now in the read set, iOS will surface `.food`
    ///        in the v3 re-auth sheet and the user's decision finally
    ///        gets recorded. Bumping the bundle version forces v2 users
    ///        to flow through the sheet one more time — they only see
    ///        the previously missing two macros + the correlation.
    ///
    /// When future read-set expansions happen, change the constant here
    /// and every install that opens the app gets exactly one re-auth
    /// sheet covering only the newly added types. Existing decisions
    /// are preserved.
    static let currentAuthBundleVersion = 3

    private static let bundleVersionKey = "hkAuthBundleVersion"

    /// Idempotent. Call at app launch and at the top of any HK-touching
    /// path that reads a type added after v1. Does nothing once the
    /// user's recorded bundle version matches `currentAuthBundleVersion`.
    ///
    /// Concurrent callers share a single in-flight request via
    /// `inFlightEnsureTask` so we don't fire two `requestAuthorization`
    /// calls in a row (one from `.task` on the root view, one from a
    /// per-query guard like `deleteFoodEntry` — both would race to
    /// bump the flag and could leave iOS in an inconsistent state).
    ///
    /// The stored bundle version is only bumped if `requestAuthorization`
    /// actually completed without throwing. If the call fails (e.g.
    /// HealthKit unavailable mid-call), the next caller retries — better
    /// than silently marking as "current" while the user still has
    /// `.notDetermined` types.
    @MainActor
    func ensureAuthorizationCurrent() async {
        guard isAvailable else { return }
        let stored = UserDefaults.standard.integer(forKey: Self.bundleVersionKey)
        if stored >= Self.currentAuthBundleVersion { return }

        // Coalesce concurrent callers onto a single in-flight Task.
        if let existing = Self.inFlightEnsureTask {
            await existing.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            // Re-check inside the task in case another caller already
            // completed between the early-return and here.
            let latest = UserDefaults.standard.integer(forKey: Self.bundleVersionKey)
            if latest >= Self.currentAuthBundleVersion { return }

            let succeeded = await self.requestAuthorization()
            // Only bump the version if the request itself actually went
            // through. A `false` result means HealthKit threw — pretending
            // the bundle is current would re-strand us.
            guard succeeded else { return }

            UserDefaults.standard.set(Self.currentAuthBundleVersion, forKey: Self.bundleVersionKey)
            // The per-site gating flags (introduced in P3) would
            // otherwise fire duplicate prompts at the Weight toggle /
            // workout-save / HR view sites right after this bundle-
            // level prompt. Mark them as already-asked — the system
            // sheet just covered all their types.
            for key in ["hasRequestedHRAuth", "hasRequestedWeightAuth", "hasRequestedWorkoutAuth"] {
                UserDefaults.standard.set(true, forKey: key)
            }
        }
        Self.inFlightEnsureTask = task
        await task.value
        // Clear so a future bundle-version bump can re-run cleanly.
        // On success this is a no-op (early-return guards it next time);
        // on failure it lets the next caller retry.
        Self.inFlightEnsureTask = nil
    }

    /// Coalesces concurrent ensureAuthorizationCurrent callers. MainActor-
    /// confined access via `ensureAuthorizationCurrent`'s `@MainActor`.
    @MainActor
    private static var inFlightEnsureTask: Task<Void, Never>?

    // MARK: - Workout

    /// Saves a completed workout to Apple Health / Fitness app.
    func saveWorkoutToHealth(
        startDate: Date,
        endDate: Date,
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining
    ) async {
        guard isAvailable else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        await withCheckedContinuation { continuation in
            builder.beginCollection(withStart: startDate) { success, error in
                guard success else {
                    print("[HealthKit] beginCollection failed: \(String(describing: error))")
                    continuation.resume()
                    return
                }
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

    // MARK: - Water

    func saveWater(ml: Double, date: Date) async {
        guard isAvailable else { return }
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        do {
            try await healthStore.save(sample)
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
        // The dietary-macro habit triggers (.dietaryProtein/Carbs/Fat)
        // resolve to v2/v3 read types. If the user is still on a stored
        // bundle version that predates those types, the underlying
        // HKStatisticsQuery would throw "Authorization to read … is
        // disallowed". Block on the bundle ensure first so the per-type
        // decision is recorded before any query fires.
        await ensureAuthorizationCurrent()
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
        default:
            return 0
        }
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

    /// Saves a food diary entry as an HKCorrelation of type .food containing individual macro samples.
    /// Returns the correlation UUID, which should be stored on DiaryEntry.healthKitCorrelationID.
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
        // Ensure auth for v2 types (macros + food correlation) is settled
        // before HealthKit touches the correlation machinery. Idempotent —
        // a user who's already on v2 falls through immediately.
        await ensureAuthorizationCurrent()

        var samples: [HKQuantitySample] = []

        let typeValuePairs: [(HKQuantityTypeIdentifier, HKUnit, Double)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), calories),
            (.dietaryProtein,        .gram(),         protein),
            (.dietaryCarbohydrates,  .gram(),         carbs),
            (.dietaryFatTotal,       .gram(),         fat),
            (.dietaryFiber,          .gram(),         fiber),
        ]
        for (identifier, unit, value) in typeValuePairs where value > 0 {
            let qty = HKQuantity(unit: unit, doubleValue: value)
            samples.append(HKQuantitySample(type: HKQuantityType(identifier), quantity: qty, start: date, end: date))
        }

        guard !samples.isEmpty else { return nil }

        let correlation = HKCorrelation(
            type: HKCorrelationType(.food),
            start: date,
            end: date,
            objects: Set(samples),
            metadata: [HKMetadataKeyFoodType: foodName, "HKMealSlot": mealType]
        )
        do {
            try await healthStore.save(correlation)
            return correlation.uuid
        } catch {
            print("[HealthKit] Failed to save food correlation: \(error)")
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

    func deleteFoodEntry(correlationID: UUID) async {
        guard isAvailable else { return }
        // THE crash vector on v1 users before this fix. Without the ensure
        // call, the HKSampleQueryDescriptor below throws
        //   NSInvalidArgumentException("Authorization to read the
        //   following types is disallowed: HKCorrelationTypeIdentifierFood")
        // because iOS never collected a per-type decision for .food on
        // that user's auth grant. `ensureAuthorizationCurrent` forces the
        // v2 auth sheet, which materializes the .food decision before we
        // touch the query.
        await ensureAuthorizationCurrent()

        // After the ensure call, `.food` has either been authorized (query
        // works) or denied (query returns no results, no throw). Either
        // outcome is safe.
        let predicate = HKQuery.predicateForObject(with: correlationID)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.correlation(type: HKCorrelationType(.food), predicate: predicate)],
            sortDescriptors: []
        )
        do {
            let results = try await descriptor.result(for: healthStore)
            guard let correlation = results.first else { return }
            try await healthStore.delete(correlation)
        } catch {
            print("[HealthKit] Failed to delete food correlation: \(error)")
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
    ]
}
