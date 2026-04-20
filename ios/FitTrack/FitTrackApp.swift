import SwiftUI
import SwiftData
import WatchConnectivity
import os.log

@main
struct FitTrackApp: App {
    let container: ModelContainer

    init() {
        let config = ModelConfiguration(cloudKitDatabase: .none)

        do {
            container = try ModelContainer(
                for:
                    Exercise.self, Workout.self, WorkoutSet.self,
                    UserProfile.self, Food.self, DiaryEntry.self,
                    Habit.self, HabitCompletion.self,
                    WeightEntry.self, JournalEntry.self,
                    WorkoutTemplate.self, TemplateExercise.self,
                    BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
                configurations: config
            )
        } catch {
#if DEBUG
            // DEBUG-only escape hatch: wipe the local store to unblock
            // iterative schema changes during development. This block is
            // compiled out of Release builds — production users always see
            // the fatalError below instead of silent data loss.
            let log = Logger(subsystem: "com.danieldavis16.fittrack", category: "storage")
            log.warning("⚠️ ModelContainer init failed in DEBUG — wiping store: \(error)")
            let url = config.url
            [url,
             URL(fileURLWithPath: url.path + "-wal"),
             URL(fileURLWithPath: url.path + "-shm")]
                .forEach { try? FileManager.default.removeItem(at: $0) }
            do {
                container = try ModelContainer(
                    for:
                        Exercise.self, Workout.self, WorkoutSet.self,
                        UserProfile.self, Food.self, DiaryEntry.self,
                        Habit.self, HabitCompletion.self,
                        WeightEntry.self, JournalEntry.self,
                        WorkoutTemplate.self, TemplateExercise.self,
                        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
                    configurations: config
                )
            } catch {
                fatalError("ModelContainer failed even after DEBUG store wipe: \(error)")
            }
#else
            // In production, a failed migration is a hard stop.
            // Add a new SchemaMigrationPlan stage for any schema change
            // before shipping rather than silently wiping user data.
            fatalError("ModelContainer init failed — add a migration stage for this schema change: \(error)")
#endif
        }

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
