import HealthKit
import SwiftData
import Combine

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let weightType = HKQuantityType(.bodyMass)
        let heartRateType = HKQuantityType(.heartRate)
        do {
            try await healthStore.requestAuthorization(
                toShare: [weightType],
                read: [weightType, heartRateType]
            )
            return true
        } catch {
            print("HealthKit auth failed: \(error)")
            return false
        }
    }

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
}
