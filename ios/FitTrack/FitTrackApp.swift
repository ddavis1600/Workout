import SwiftUI
import SwiftData
import WatchConnectivity
import os.log

@main
struct FitTrackApp: App {
    let container: ModelContainer

    init() {
        let config = ModelConfiguration(cloudKitDatabase: .automatic)

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
            fatalError("ModelContainer init failed: \(error)")
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
