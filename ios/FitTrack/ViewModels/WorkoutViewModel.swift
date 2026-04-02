import Foundation
import SwiftData
import SwiftUI

@Observable
final class WorkoutViewModel {

    private var modelContext: ModelContext

    var workouts: [Workout] = []
    var exercises: [Exercise] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetching

    func fetchWorkouts() {
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        workouts = (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchExercises(muscleGroup: String? = nil) {
        var descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        if let muscleGroup {
            descriptor.predicate = #Predicate<Exercise> { exercise in
                exercise.muscleGroup == muscleGroup
            }
        }
        exercises = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Mutations

    func saveWorkout(_ workout: Workout) {
        modelContext.insert(workout)
        try? modelContext.save()
        fetchWorkouts()
    }

    func deleteWorkout(_ workout: Workout) {
        modelContext.delete(workout)
        try? modelContext.save()
        fetchWorkouts()
    }

    // MARK: - Progress

    func progressData(for exercise: Exercise) -> [(date: Date, maxWeight: Double)] {
        let descriptor = FetchDescriptor<WorkoutSet>()
        guard let allSets = try? modelContext.fetch(descriptor) else { return [] }

        let relevantSets = allSets.filter { $0.exercise?.name == exercise.name }

        var grouped: [Date: Double] = [:]
        for set in relevantSets {
            guard let date = set.workout?.date, let weight = set.weight else { continue }
            let day = date.startOfDay
            grouped[day] = max(grouped[day] ?? 0, weight)
        }

        return grouped
            .map { (date: $0.key, maxWeight: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
