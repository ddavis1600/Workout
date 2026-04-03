import Foundation
import SwiftData

enum DataController {
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
