import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Exercise.self,
            Workout.self,
            WorkoutSet.self,
            UserProfile.self,
            Food.self,
            DiaryEntry.self,
            Habit.self,
            HabitCompletion.self,
            WeightEntry.self
        ])

        // Try CloudKit first for iCloud sync; fall back to local-only if it fails
        // (CloudKit requires signed-in iCloud account and provisioned container)
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        let localConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            container = try ModelContainer(for: schema, configurations: cloudConfig)
        } catch {
            // CloudKit not available (e.g. simulator, no iCloud account) — use local storage
            do {
                container = try ModelContainer(for: schema, configurations: localConfig)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }

        // Seed data on first launch
        let context = ModelContext(container)
        DataController.seedDataIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
