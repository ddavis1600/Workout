import SwiftUI
import SwiftData
import WatchConnectivity

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
            WeightEntry.self,
            JournalEntry.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            BodyMeasurement.self,
            FoodFavorite.self,
            ProgressPhoto.self,
        ])

        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema changed — delete old store and companion WAL/SHM files, then retry
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }

        // Seed data on first launch
        let context = ModelContext(container)
        DataController.seedDataIfNeeded(context: context)

        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
