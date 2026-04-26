import Foundation
import SwiftData

enum PRType: String {
    case maxWeight = "Max Weight"
    case maxReps = "Max Reps"
    case maxVolume = "Max Volume"
}

struct PRRecord {
    let type: PRType
    let value: Double
    let exerciseName: String
    let date: Date
}

enum PRService {
    static func checkForPRs(exerciseName: String, reps: Int?, weight: Double?, allSets: [WorkoutSet]) -> [PRType] {
        guard let reps = reps, let weight = weight, reps > 0, weight > 0 else { return [] }

        let previousSets = allSets.filter { $0.exercise?.name == exerciseName }
        var prs: [PRType] = []

        // Max weight PR
        let previousMaxWeight = previousSets.compactMap(\.weight).max() ?? 0
        if weight > previousMaxWeight {
            prs.append(.maxWeight)
        }

        // Max reps PR (at same or higher weight)
        let previousMaxReps = previousSets
            .filter { ($0.weight ?? 0) >= weight }
            .compactMap(\.reps)
            .max() ?? 0
        if reps > previousMaxReps {
            prs.append(.maxReps)
        }

        // Max volume PR (weight × reps)
        let volume = weight * Double(reps)
        let previousMaxVolume = previousSets.compactMap { set -> Double? in
            guard let r = set.reps, let w = set.weight else { return nil }
            return w * Double(r)
        }.max() ?? 0
        if volume > previousMaxVolume {
            prs.append(.maxVolume)
        }

        return prs
    }

    static func allPRs(for exerciseName: String, allSets: [WorkoutSet]) -> [PRRecord] {
        let exerciseSets = allSets.filter { $0.exercise?.name == exerciseName }
        var records: [PRRecord] = []

        // Best max weight
        if let best = exerciseSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
           let w = best.weight, w > 0 {
            records.append(PRRecord(type: .maxWeight, value: w, exerciseName: exerciseName, date: best.workout?.date ?? Date()))
        }

        // Best volume
        if let best = exerciseSets.max(by: {
            (($0.weight ?? 0) * Double($0.reps ?? 0)) < (($1.weight ?? 0) * Double($1.reps ?? 0))
        }), let w = best.weight, let r = best.reps, w > 0, r > 0 {
            records.append(PRRecord(type: .maxVolume, value: w * Double(r), exerciseName: exerciseName, date: best.workout?.date ?? Date()))
        }

        return records
    }
}
