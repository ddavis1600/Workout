import Foundation
import SwiftData

final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            Exercise.self,
            Workout.self,
            WorkoutSet.self,
            UserProfile.self,
            Food.self,
            DiaryEntry.self
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Seeds default exercises and foods on first launch when the database is empty.
    static func seedDataIfNeeded(context: ModelContext) {
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let exerciseCount = (try? context.fetchCount(exerciseDescriptor)) ?? 0

        guard exerciseCount == 0 else { return }

        SeedData.seedExercises(context: context)
        SeedData.seedFoods(context: context)

        do {
            try context.save()
        } catch {
            print("Failed to save seed data: \(error)")
        }
    }
}
