import Foundation
import SwiftData
import HealthKit

/// Commits the current `WorkoutSessionManager` state to SwiftData + HealthKit
/// and ends the session. Pulled out of LogWorkoutView so the same flow can
/// be kicked off from multiple surfaces:
///   - The phone's Save toolbar button in LogWorkoutView
///   - ContentView's global "watch tapped Stop" observer (fires even when
///     the full-screen logger is hidden behind the mini bar — previously
///     the save-on-watch-stop handler lived inside LogWorkoutView so it
///     silently did nothing when the workout was minimized)
///
/// When the watch has been live-tracking GPS, waits up to 1.5 s for the
/// watch's final payload (distance / elevation / full route) so the saved
/// Workout has complete data.
@MainActor
enum WorkoutPersistence {

    /// Persist the session as a Workout, write to HealthKit, clear the
    /// session. Safe to call from anywhere; no-ops if no session is active.
    static func saveAndEnd(context: ModelContext, unitSystem: String) async {
        let session = WorkoutSessionManager.shared
        guard session.isActive else { return }

        // Let the watch know we're wrapping up. If the watch is live-tracking
        // GPS, wait briefly for its final payload so distance/elevation/route
        // land on the saved Workout instead of arriving after we've
        // committed and end()'d the session.
        WatchConnectivityManager.shared.sendStopWorkout()
        if session.watchTrackingActive {
            let deadline = Date().addingTimeInterval(1.5)
            while session.watchTrackingActive && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        let elapsed         = session.elapsedSeconds
        let workoutEndDate  = Date()
        let workoutStartDate = session.startDate
            ?? workoutEndDate.addingTimeInterval(-Double(max(elapsed, 1)))
        let durationMin     = max(1, Int(round(Double(elapsed) / 60.0)))

        // Prefer live GPS distance over any manually-typed value. Only
        // stored for distance activities.
        let distanceMeters: Double? = {
            guard Workout.isDistanceType(session.workoutType) else { return nil }
            if session.liveDistanceMeters > 0 { return session.liveDistanceMeters }
            guard let value = Double(session.distanceInput.trimmingCharacters(in: .whitespaces)),
                  value > 0 else { return nil }
            return unitSystem == "imperial" ? value / 0.000621371 : value * 1000.0
        }()

        // Elevation comes only from live GPS — we can't meaningfully infer
        // it from a typed distance.
        let elevationGain: Double? = {
            guard Workout.isDistanceType(session.workoutType),
                  session.liveElevationGain > 0 else { return nil }
            return session.liveElevationGain
        }()

        let workout = Workout(
            name: session.workoutName,
            date: session.workoutDate,
            notes: session.workoutNotes,
            durationMinutes: elapsed > 0 ? durationMin : nil,
            photoData: session.selectedPhotoData,
            workoutType: session.workoutType,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGain,
            routeData: session.liveRouteData
        )

        // Heart-rate stats come from the session-local HeartRateService.
        let hrService = session.heartRateService
        if hrService.sessionAvgBPM > 0 {
            workout.avgHeartRate = hrService.sessionAvgBPM
            workout.maxHeartRate = hrService.sessionMaxBPM
            workout.minHeartRate = hrService.sessionMinBPM
            let age = UserDefaults.standard.integer(forKey: "heartRateUserAge")
            let maxHR = 220 - (age > 0 ? age : 25)
            let durations = hrService.zoneDurations(maxHR: maxHR)
            workout.hrZone1Seconds = durations[1]
            workout.hrZone2Seconds = durations[2]
            workout.hrZone3Seconds = durations[3]
            workout.hrZone4Seconds = durations[4]
            workout.hrZone5Seconds = durations[5]
        }

        context.insert(workout)

        // Exercise groups → WorkoutSets.
        for group in session.exerciseGroups {
            let exercise = group.exercise
            if exercise.modelContext == nil {
                context.insert(exercise)
            }
            for (index, setEntry) in group.sets.enumerated() {
                let workoutSet = WorkoutSet(
                    exercise: exercise,
                    setNumber: index + 1,
                    reps:   Int(setEntry.reps),
                    weight: Double(setEntry.weight),
                    rpe:    Double(setEntry.rpe),
                    notes:  setEntry.notes
                )
                if workout.sets != nil {
                    workout.sets!.append(workoutSet)
                } else {
                    workout.sets = [workoutSet]
                }
                context.insert(workoutSet)
            }
        }

        do {
            try context.save()
        } catch {
            print("[WorkoutPersistence] save failed: \(error)")
        }

        // Write to Apple Health. Fire-and-forget — HK failures shouldn't
        // block UI dismiss.
        //
        // Gate the auth prompt (P3 sweep): without this, every workout
        // save re-fired `requestAuthorization()` even when the user had
        // long since granted (or denied). XPC round-trip plus a brief
        // sheet flash on some paths. After the first save the flag is
        // set; subsequent saves skip the call. Status check on the
        // workout write type also re-prompts if Settings revoked.
        let activityType = HealthKitManager.hkActivityType(from: session.workoutType)
        let hk = HealthKitManager.shared
        if hk.isAvailable {
            if hk.shouldRequestAuthorization(
                writeType: HKWorkoutType.workoutType(),
                flagKey: "hasRequestedWorkoutAuth"
            ) {
                _ = await hk.requestAuthorization()
                hk.markAuthorizationRequested(flagKey: "hasRequestedWorkoutAuth")
            }
            // Skip the actual write cleanly when the user denied —
            // saveWorkoutToHealth would otherwise log a non-fatal
            // error to the console on every denied save.
            let status = hk.healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
            if status == .sharingAuthorized {
                await hk.saveWorkoutToHealth(
                    startDate: workoutStartDate,
                    endDate:   workoutEndDate,
                    activityType: activityType,
                    distanceMeters: distanceMeters
                )
            }
        }

        session.end()
    }
}
