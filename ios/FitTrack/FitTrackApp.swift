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

        // Use local storage for now; change to .automatic for iCloud sync on real devices
        #if targetEnvironment(simulator)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        #else
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        #endif

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
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
