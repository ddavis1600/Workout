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
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKWorkoutType.workoutType(),
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
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: allReadTypes)
            return true
        } catch {
            print("HealthKit auth failed: \(error)")
            return false
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

    func fetchWaterToday() async -> Double {
        return await fetchDailySumQuantity(
            typeIdentifier: .dietaryWater,
            unit: .literUnit(with: .milli),
            date: Date()
        )
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
