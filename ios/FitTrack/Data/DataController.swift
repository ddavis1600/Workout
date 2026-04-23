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

    /// De-duplicate Exercises by name (case-insensitive, trimmed). Classic
    /// CloudKit + seed-on-first-launch trap: on a reinstall, the local store
    /// is empty so `seedDataIfNeeded` fires — then CloudKit syncs the user's
    /// historical exercises back in and we end up with two of each. Since
    /// Exercise isn't CloudKit-uniquable (unique constraints aren't allowed
    /// with NSPersistentCloudKitContainer), we fix it on launch by folding
    /// duplicates into one record.
    ///
    /// The kept record is the one with the most existing WorkoutSet refs so
    /// we lose no history. Remaining duplicates have their WorkoutSets
    /// re-parented to the kept record before deletion.
    static func cleanupDuplicateExercises(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        guard let all = try? context.fetch(descriptor), !all.isEmpty else { return }

        let groups = Dictionary(grouping: all) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        var deleted = 0
        for (_, rows) in groups where rows.count > 1 {
            // Prefer the exercise that already has workout-set history.
            let sorted = rows.sorted { ($0.workoutSets ?? []).count > ($1.workoutSets ?? []).count }
            let keeper = sorted[0]
            for dup in sorted.dropFirst() {
                for ws in (dup.workoutSets ?? []) {
                    ws.exercise = keeper
                }
                context.delete(dup)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? context.save()
            print("[DataController] cleaned up \(deleted) duplicate exercise(s)")
        }
    }
}
