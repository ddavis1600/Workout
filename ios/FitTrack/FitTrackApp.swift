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
            DiaryEntry.self
        ])
        let config = ModelConfiguration(schema: schema)
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
