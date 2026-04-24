import Foundation
import HealthKit
import WatchConnectivity

class WatchHeartRateService: ObservableObject {
    @Published var currentBPM: Int = 0
    @Published var isMonitoring: Bool = false
    @Published var lastUpdated: Date?

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?

    var zoneName: String {
        switch currentBPM {
        case 0..<90:    return "–"
        case 90..<115:  return "Warm Up"
        case 115..<135: return "Fat Burn"
        case 135..<155: return "Cardio"
        case 155..<175: return "Hard"
        default:        return "Max"
        }
    }

    var zoneColor: String {
        switch currentBPM {
        case 0..<90:    return "gray"
        case 90..<115:  return "gray"
        case 115..<135: return "blue"
        case 135..<155: return "green"
        case 155..<175: return "orange"
        default:        return "red"
        }
    }

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        // Ask for the same superset the workout session requests so we
        // don't create a new un-decided type-tuple and trigger an
        // unnecessary HK permission sheet. If the user already granted
        // via the workout-start flow, this is a silent no-op.
        let shareTypes: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.bodyMass),
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
        let readTypes: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.bodyMass),
            hrType,
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ]
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] granted, _ in
            guard granted else { return }
            self?.beginQuery()
        }
    }

    func stopMonitoring() {
        if let q = query { healthStore.stop(q) }
        query = nil
        DispatchQueue.main.async { self.isMonitoring = false }
    }

    private func beginQuery() {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let anchorQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handle(samples)
        }
        anchorQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handle(samples)
        }
        query = anchorQuery
        healthStore.execute(anchorQuery)
        DispatchQueue.main.async { self.isMonitoring = true }
    }

    private func handle(_ samples: [HKSample]?) {
        guard let hrSamples = samples as? [HKQuantitySample],
              let latest = hrSamples.last else { return }
        let bpm = Int(latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        DispatchQueue.main.async {
            self.currentBPM = bpm
            self.lastUpdated = latest.startDate
            WatchSessionManager.shared.sendMessage(["heartRate": Double(bpm)])
        }
    }
}
