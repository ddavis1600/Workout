import SwiftUI
import SwiftData
import WatchConnectivity
import os.log

@main
struct CairnApp: App {
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
                    migrationPlan: CairnMigrationPlan.self,
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
                    migrationPlan: CairnMigrationPlan.self,
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
                        migrationPlan: CairnMigrationPlan.self,
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

    /// Pre-onboarding gate (F-theme-pre). Flipped to `true` when the
    /// user taps Continue on `ThemePickerScreen`. Two flags rather
    /// than one because we want the user's theme choice locked in
    /// BEFORE `OnboardingFlow` mounts — putting the palette tap
    /// inside the wizard caused the wizard to restart on every tap
    /// (palette change → root rebuild → wizard `@State` destroyed).
    @AppStorage("hasCompletedPreOnboarding") private var hasCompletedPreOnboarding = false

    /// Brightness pref duplicated here from `ContentView` so the
    /// pre-onboarding screen + wizard (which render BEFORE
    /// ContentView mounts) get the user's chosen light/dark mode.
    /// `colorTheme` is NOT read here — palette tinting is driven
    /// by per-token `ThemePalette.current` resolution at leaf
    /// views, not by a root-level rebuild trigger.
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some Scene {
        WindowGroup {
            // Three-way root switch. The order matters: pre-onboarding
            // first so a fresh install sees the palette picker, then
            // the multi-step wizard, then the main app.
            Group {
                if !hasCompletedPreOnboarding {
                    ThemePickerScreen {
                        // Continue tap → flip the gate, which naturally
                        // re-evaluates this Group and slides
                        // OnboardingFlow in. Animation kept short so
                        // the hand-off doesn't feel laggy.
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasCompletedPreOnboarding = true
                        }
                    }
                } else if !hasCompletedOnboarding {
                    OnboardingFlow()
                } else {
                    ContentView()
                }
            }
            // Brightness pref → SwiftUI color scheme. `nil` = follow
            // system. Lives on the WindowGroup root so every branch
            // is covered. Safe at the root because preferredColorScheme
            // is environment propagation, not a subtree rebuild.
            .preferredColorScheme(
                appTheme == "system" ? nil :
                appTheme == "dark"   ? .dark : .light
            )
            // NB: NO `.id(colorTheme + appTheme)` here — that
            // modifier rebuilds the entire subtree when the palette
            // changes, which destroyed `OnboardingFlow`'s @State on
            // every swatch tap (Daniel: "wizard restarts from
            // scratch"). The palette-rebuild trigger is now scoped
            // to ContentView (see ContentView.swift) so it only
            // re-paints the main app subtree.
            //
            // ThemePickerScreen handles its own live preview because
            // its body reads `@AppStorage("colorTheme")`, so the
            // body re-runs on tap. OnboardingFlow doesn't change
            // theme at all, so it doesn't need a rebuild trigger
            // either.
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
