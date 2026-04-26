import SwiftUI
import SwiftData
import WatchConnectivity
import os.log

@main
struct FitTrackApp: App {
    let container: ModelContainer

    init() {
        let log = Logger(subsystem: "com.danieldavis16.cairn", category: "storage")

        // Attempt 1: CloudKit-backed store (requires iCloud entitlement in provisioning profile).
        // Falls back to local storage if CloudKit is unavailable (entitlement not yet provisioned,
        // no iCloud account, or airplane mode on first launch). App always launches either way.
        let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
        var cloudKitError: Error? = nil
        let cloudContainer: ModelContainer? = {
            do {
                return try ModelContainer(
                    for:
                        Exercise.self, Workout.self, WorkoutSet.self,
                        UserProfile.self, Food.self, DiaryEntry.self,
                        Habit.self, HabitCompletion.self,
                        WeightEntry.self, JournalEntry.self,
                        WorkoutTemplate.self, TemplateExercise.self,
                        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
                    migrationPlan: FitTrackMigrationPlan.self,
                    configurations: cloudConfig)
            } catch {
                cloudKitError = error
                return nil
            }
        }()

        if let c = cloudContainer {
            log.info("✅ ModelContainer initialised with CloudKit sync")
            container = c
        } else {
            // CloudKit unavailable — fall back to local store so the app always launches.
            log.warning("⚠️ CloudKit ModelContainer failed: \(String(describing: cloudKitError)) — falling back to local store")
            let localConfig = ModelConfiguration(cloudKitDatabase: .none)
            do {
                container = try ModelContainer(
                    for:
                        Exercise.self, Workout.self, WorkoutSet.self,
                        UserProfile.self, Food.self, DiaryEntry.self,
                        Habit.self, HabitCompletion.self,
                        WeightEntry.self, JournalEntry.self,
                        WorkoutTemplate.self, TemplateExercise.self,
                        BodyMeasurement.self, FoodFavorite.self, ProgressPhoto.self,
                    migrationPlan: FitTrackMigrationPlan.self,
                    configurations: localConfig
                )
            } catch {
#if DEBUG
                // Last resort in DEBUG: wipe the local store and retry.
                log.warning("⚠️ Local ModelContainer also failed — wiping store: \(error)")
                let url = localConfig.url
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
                        migrationPlan: FitTrackMigrationPlan.self,
                        configurations: localConfig
                    )
                } catch {
                    fatalError("ModelContainer failed even after store wipe: \(error)")
                }
#else
                fatalError("ModelContainer init failed: \(error)")
#endif
            }
        }

        let context = ModelContext(container)
        DataController.seedDataIfNeeded(context: context)
        // CloudKit may re-sync exercises that were already seeded locally,
        // producing duplicates. Collapse those on every launch so the
        // exercise picker stays clean.
        DataController.cleanupDuplicateExercises(context: context)

        // Seed the Home Screen widget snapshot so first-launch widgets
        // render real values rather than the placeholder zeros. Save
        // paths refresh it later; this is the cold-start guarantee.
        WidgetSnapshot.refresh(from: context)

        WatchConnectivityManager.shared.activate()
    }

    @Environment(\.scenePhase) private var scenePhase

    /// First-launch gate. Set to `true` by `OnboardingFlow.finish()`
    /// after the user finishes the multi-step intro (F5). Stored in
    /// `UserDefaults` rather than `UserProfile` because we need to
    /// read it before any SwiftData query — the flag determines
    /// whether we even show the main UI.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            // Single switch on the AppStorage flag. The transition
            // animation lives on `OnboardingFlow.finish()` so the
            // hand-off from flow → main UI feels intentional rather
            // than a hard cut.
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingFlow()
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh widgets whenever the app foregrounds. Catches data
            // changes that bypass the in-app save paths (e.g. Watch app
            // syncing a workout via WatchConnectivity).
            if newPhase == .active {
                WidgetSnapshot.refresh(from: ModelContext(container))
            }
        }
    }
}
