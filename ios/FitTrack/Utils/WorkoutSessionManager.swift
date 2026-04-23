import Foundation
import SwiftUI
import SwiftData
import Combine

/// Shared state for an in-progress workout so it survives tab switches and
/// minimize/expand cycles. Previously LogWorkoutView owned all this as @State,
/// which meant the timer and any entered sets were wiped whenever the view
/// was dismissed — including just switching tabs.
///
/// Usage:
///   - Call `start()` or `start(template:)` to begin a workout. This flips
///     `isActive = true` and `isMinimized = false`, which the presentation
///     code in WorkoutListView / ContentView watches to show the full-screen
///     logger.
///   - Call `minimize()` to hide the full-screen logger; the mini bar in
///     ContentView will render above the tab bar. Tapping it calls `expand()`.
///   - Call `end()` when the workout is saved or discarded to clear state.
///
/// The timer is derived from `startDate`, not scheduled — so it's impossible
/// to drift or lose time across dismiss/reopen cycles.
@MainActor
final class WorkoutSessionManager: ObservableObject {
    static let shared = WorkoutSessionManager()

    // MARK: - Session flags
    @Published var isActive = false
    @Published var isMinimized = false

    // MARK: - Workout fields (mirror the SwiftData Workout + form inputs)
    @Published var workoutName = ""
    @Published var workoutDate: Date = .now
    @Published var workoutNotes = ""
    @Published var workoutType: String = "strength"
    @Published var selectedPhotoData: Data? = nil
    @Published var exerciseGroups: [ExerciseGroup] = []
    /// Effective start date — shifted forward on resume so that
    /// `Date().timeIntervalSince(startDate)` always yields the correct
    /// running elapsed value. Nil until the first `start()`.
    @Published var startDate: Date? = nil
    /// When `true`, `elapsedSeconds` returns `frozenSeconds` instead of
    /// computing from `startDate`.
    @Published var isPaused: Bool = false
    /// Snapshot of elapsed seconds at the moment of pause. Nil while running.
    @Published private var frozenSeconds: Int? = nil
    /// Set when a workout is started from a template so LogWorkoutView can
    /// populate its exercise groups on first appear.
    @Published var pendingTemplate: WorkoutTemplate? = nil

    /// Lives on the session (not in LogWorkoutView) so it keeps monitoring
    /// across minimize/expand cycles — otherwise HR session data is reset
    /// every time the user expands the workout.
    let heartRateService = HeartRateService()

    private init() {}

    // MARK: - Computed

    /// Always-correct elapsed time — derived from `startDate` (while running)
    /// or the frozen snapshot (while paused). Survives view dismiss/reopen
    /// because nothing needs to keep ticking: each read computes fresh.
    var elapsedSeconds: Int {
        if isPaused, let frozen = frozenSeconds { return frozen }
        guard let s = startDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(s)))
    }

    /// "mm:ss" or "h:mm:ss" for display.
    var elapsedDisplay: String {
        let total = elapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Lifecycle

    /// Start a fresh workout (no template). If one is already active, expand
    /// it rather than starting a new one.
    func start() {
        if isActive { isMinimized = false; return }
        reset()
        isActive = true
        isMinimized = false
        startDate = .now
        heartRateService.resetSession()
        Task { await heartRateService.startMonitoring() }
    }

    /// Start a workout pre-loaded from a saved template.
    func start(template: WorkoutTemplate) {
        if isActive { isMinimized = false; return }
        reset()
        isActive = true
        isMinimized = false
        startDate = .now
        workoutName = template.name
        pendingTemplate = template
        heartRateService.resetSession()
        Task { await heartRateService.startMonitoring() }
    }

    func minimize() { isMinimized = true }
    func expand()   { isMinimized = false }

    /// Freeze the timer. elapsedSeconds will return the captured value until
    /// resume() is called.
    func pause() {
        guard !isPaused else { return }
        frozenSeconds = elapsedSeconds
        isPaused = true
    }

    /// Un-freeze the timer. Shift `startDate` forward so the computed elapsed
    /// resumes from the frozen value rather than jumping ahead.
    func resume() {
        guard isPaused else { return }
        let frozen = frozenSeconds ?? 0
        startDate = Date().addingTimeInterval(-Double(frozen))
        frozenSeconds = nil
        isPaused = false
    }

    /// Zero the timer (keeps session active, just restarts the clock).
    func resetTimer() {
        startDate = .now
        frozenSeconds = nil
        isPaused = false
    }

    /// Clear all state and mark the session inactive. Call after save or discard.
    func end() {
        heartRateService.stopMonitoring()
        reset()
        isActive = false
        isMinimized = false
    }

    private func reset() {
        workoutName = ""
        workoutDate = .now
        workoutNotes = ""
        workoutType = "strength"
        selectedPhotoData = nil
        exerciseGroups = []
        startDate = nil
        isPaused = false
        frozenSeconds = nil
        pendingTemplate = nil
    }
}

// MARK: - ExerciseGroup & SetEntry
// These used to live inside LogWorkoutView.swift but are now shared so the
// session manager (and MiniWorkoutBar) can inspect them.

struct SetEntry: Identifiable {
    let id: UUID
    var reps: String
    var weight: String
    var rpe: String
    var notes: String

    init(id: UUID = UUID(), reps: String = "", weight: String = "", rpe: String = "", notes: String = "") {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.notes = notes
    }
}

struct ExerciseGroup: Identifiable {
    let id: UUID
    var exercise: Exercise
    var sets: [SetEntry]

    init(id: UUID = UUID(), exercise: Exercise, sets: [SetEntry] = []) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
}
