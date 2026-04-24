import SwiftUI
import SwiftData
import Combine
import PhotosUI
import WatchConnectivity

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var viewModel: WorkoutViewModel

    @State private var workoutName = ""
    @State private var workoutDate = Date.now
    @State private var workoutNotes = ""
    @State private var exerciseGroups: [ExerciseGroup] = []
    @State private var showingExercisePicker = false
    @State private var showingSaveTemplate = false
    var template: WorkoutTemplate?

    // Photo state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    // Timer state
    // `hasStarted` gates the whole workout lifecycle — until the user
    // taps the big "Start" button, no timer runs, no HealthKit session
    // is begun, and no "startWorkout" message is sent to the watch. This
    // replaces the previous behavior where opening the sheet auto-started
    // everything, which meant accidentally backing out (without tapping
    // Save) still created a spurious HK workout entry.
    @State private var hasStarted = false
    @State private var elapsedSeconds: Int = 0
    @State private var timerIsRunning = false
    @State private var timerSubscription: AnyCancellable?

    // Rest timer
    @AppStorage("restTimerSeconds") private var restTimerDuration = 60
    @AppStorage("restTimerEnabled") private var restTimerEnabled = true
    @State private var showRestTimer = false

    // Heart rate
    @State private var heartRateService = HeartRateService()
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    private var userAge: Int {
        let age = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        return age > 0 ? age : 25
    }

    struct SetEntry: Identifiable {
        let id = UUID()
        var reps: String
        var weight: String
        var rpe: String
        var notes: String = ""
    }

    struct ExerciseGroup: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var sets: [SetEntry]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        timerSection
                        if showRestTimer {
                            RestTimerView(duration: restTimerDuration) {
                                withAnimation { showRestTimer = false }
                            }
                        }
                        if let watchBPM = watchManager.liveHeartRate {
                            watchHeartRateRow(bpm: watchBPM)
                        }
                        WorkoutHeartRateCard(service: heartRateService, userAge: userAge)
                        workoutInfoSection
                        photoSection
                        exerciseSections
                        addExerciseButton
                        if !exerciseGroups.isEmpty {
                            saveAsTemplateButton
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        WatchConnectivityManager.shared.sendStopWorkout()
                        dismiss()
                    }
                    .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .foregroundStyle(Color.emerald)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let initialSet = SetEntry(reps: "", weight: "", rpe: "")
                    exerciseGroups.append(ExerciseGroup(exercise: exercise, sets: [initialSet]))
                }
            }
            .sheet(isPresented: $showingSaveTemplate) {
                SaveTemplateSheet(exerciseGroups: exerciseGroups.map { group in
                    let lastSet = group.sets.last
                    return (
                        exerciseName: group.exercise.name,
                        muscleGroup: group.exercise.muscleGroup,
                        setCount: group.sets.count,
                        reps: lastSet?.reps ?? "",
                        weight: lastSet?.weight ?? ""
                    )
                })
            }
            .task {
                // Pre-populate exercises if launched from a template, but
                // DO NOT start the timer / HR / watch — wait for the user
                // to tap the Start button in the ready-state card.
                loadTemplate()
            }
            .onDisappear {
                // stopTimer/stopMonitoring are no-ops if nothing was
                // actually started, so calling them is safe either way.
                stopTimer()
                heartRateService.stopMonitoring()
            }
            .onChange(of: watchManager.pendingWorkoutStop) { _, stop in
                if stop {
                    watchManager.pendingWorkoutStop = false
                    // Only auto-save on a watch Stop if the user actually
                    // began a workout on this device. Without this guard,
                    // merely opening LogWorkoutView and then receiving any
                    // stray `stopWorkout` WatchConnectivity message (even
                    // a stale queued one from a previous session) saves a
                    // blank Workout — which is how ghost workouts were
                    // appearing in Daniel's list.
                    if hasStarted {
                        saveWorkout()
                    }
                }
            }
        }
    }

    // MARK: - Watch Heart Rate

    private func watchHeartRateRow(bpm: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.title3)
                .foregroundStyle(Color.emerald)
            Text("Watch")
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(bpm))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("BPM")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.slateText)
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    // MARK: - Timer

    @ViewBuilder
    private var timerSection: some View {
        if !hasStarted {
            readyStateCard
        } else {
            runningTimerCard
        }
    }

    /// Before the user taps Start, the view is "ready": exercises / sets /
    /// notes can be pre-populated (e.g. from a template or a manual build),
    /// but no timer runs, no HK session opens, and the watch isn't signalled.
    private var readyStateCard: some View {
        VStack(spacing: 10) {
            Text("Ready")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.slateText)
                .textCase(.uppercase)

            Text("00:00:00")
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.slateText.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                beginWorkout()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    /// Existing live-workout card — elapsed time with Pause/Resume + Reset.
    private var runningTimerCard: some View {
        VStack(spacing: 10) {
            Text(formattedElapsedTime)
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.emerald)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 20) {
                Button {
                    if timerIsRunning {
                        stopTimer()
                    } else {
                        startTimer()
                    }
                    timerIsRunning.toggle()
                } label: {
                    Label(timerIsRunning ? "Pause" : "Resume",
                          systemImage: timerIsRunning ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.emerald)
                }

                Button {
                    stopTimer()
                    elapsedSeconds = 0
                    timerIsRunning = false
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.slateText)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    /// Transition from "ready" → actively timing. Kicks off the timer
    /// and begins HR monitoring. Called from the Start button in
    /// `readyStateCard`. HR samples flow through HealthKit regardless
    /// of which device (phone or watch) the user taps Start on, so we
    /// don't need to signal the watch from here.
    private func beginWorkout() {
        hasStarted = true
        timerIsRunning = true
        startTimer()
        heartRateService.resetSession()
        Task { await heartRateService.startMonitoring() }
    }

    private var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func startTimer() {
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                elapsedSeconds += 1
            }
    }

    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    // MARK: - Workout Info

    private var workoutInfoSection: some View {
        VStack(spacing: 14) {
            TextField("Workout Name (optional)", text: $workoutName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)

            DatePicker("Date", selection: $workoutDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.emerald)
                .foregroundStyle(Color.ink)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            TextField("Notes (optional)", text: $workoutNotes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.slateText)

            if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding(8)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(selectedPhotoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.emerald.opacity(0.3), lineWidth: 1)
                    )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    // Downscale + JPEG encode runs on a detached userInitiated
                    // Task inside ImageCompression — keeps the PhotosPicker
                    // callback from hitching the main actor while we chew on
                    // a 12 MP capture (80–200 ms on A15).
                    selectedPhotoData = await ImageCompression.compressedJPEG(from: data) ?? data
                }
            }
        }
    }

    // MARK: - Exercise Sections

    private var exerciseSections: some View {
        ForEach($exerciseGroups) { $group in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(group.exercise.name)
                        .font(.headline)
                        .foregroundStyle(Color.emerald)
                    Spacer()
                    Button {
                        withAnimation {
                            exerciseGroups.removeAll { $0.id == group.id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.slateText)
                    }
                }

                // Header row
                HStack(spacing: 10) {
                    Text("#")
                        .frame(width: 28)
                    Text("Reps")
                        .frame(maxWidth: .infinity)
                    Text("Weight")
                        .frame(maxWidth: .infinity)
                    Text("RPE")
                        .frame(width: 60)
                    Spacer()
                        .frame(width: 28)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.slateText)

                ForEach($group.sets) { $setEntry in
                    let index = group.sets.firstIndex(where: { $0.id == setEntry.id }) ?? 0
                    SetRowView(
                        setNumber: index + 1,
                        reps: $setEntry.reps,
                        weight: $setEntry.weight,
                        rpe: $setEntry.rpe,
                        notes: $setEntry.notes,
                        onDelete: {
                            withAnimation {
                                group.sets.removeAll { $0.id == setEntry.id }
                            }
                        }
                    )
                }

                Button {
                    let previousSet = group.sets.last
                    let newSet = SetEntry(
                        reps: previousSet?.reps ?? "",
                        weight: previousSet?.weight ?? "",
                        rpe: previousSet?.rpe ?? ""
                    )
                    withAnimation {
                        group.sets.append(newSet)
                    }
                    if restTimerEnabled && group.sets.count > 1 {
                        withAnimation { showRestTimer = true }
                    }
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.emerald)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Add Exercise

    private var addExerciseButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            Label("Add Exercise", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.emerald)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.emerald.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Save as Template

    private var saveAsTemplateButton: some View {
        Button {
            showingSaveTemplate = true
        } label: {
            Label("Save as Template", systemImage: "doc.badge.plus")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.emerald)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Load Template

    private func loadTemplate() {
        guard let template = template, exerciseGroups.isEmpty else { return }
        workoutName = template.name

        for te in (template.exercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let searchName = te.exerciseName
            let descriptor = FetchDescriptor<Exercise>()
            let allExercises = (try? modelContext.fetch(descriptor)) ?? []
            let exercise = allExercises.first(where: { $0.name == searchName })
                ?? Exercise(name: te.exerciseName, muscleGroup: te.muscleGroup)

            var sets: [SetEntry] = []
            for _ in 0..<te.defaultSets {
                sets.append(SetEntry(
                    reps: te.defaultReps > 0 ? "\(te.defaultReps)" : "",
                    weight: te.defaultWeight > 0 ? "\(te.defaultWeight)" : "",
                    rpe: ""
                ))
            }
            exerciseGroups.append(ExerciseGroup(exercise: exercise, sets: sets))
        }
    }

    // MARK: - Save

    private func saveWorkout() {
        stopTimer()
        heartRateService.stopMonitoring()
        WatchConnectivityManager.shared.sendStopWorkout()

        let workoutEndDate   = Date()
        let workoutStartDate = workoutEndDate.addingTimeInterval(-Double(max(elapsedSeconds, 1)))
        let durationMin      = max(1, Int(round(Double(elapsedSeconds) / 60.0)))

        let workout = Workout(
            name: workoutName,
            date: workoutDate,
            notes: workoutNotes,
            durationMinutes: elapsedSeconds > 0 ? durationMin : nil,
            photoData: selectedPhotoData
        )

        // Save heart rate data if available
        if heartRateService.sessionAvgBPM > 0 {
            workout.avgHeartRate = heartRateService.sessionAvgBPM
            workout.maxHeartRate = heartRateService.sessionMaxBPM
            workout.minHeartRate = heartRateService.sessionMinBPM
            let maxHR = 220 - userAge
            let durations = heartRateService.zoneDurations(maxHR: maxHR)
            workout.hrZone1Seconds = durations[1]
            workout.hrZone2Seconds = durations[2]
            workout.hrZone3Seconds = durations[3]
            workout.hrZone4Seconds = durations[4]
            workout.hrZone5Seconds = durations[5]
        }

        modelContext.insert(workout)

        for group in exerciseGroups {
            let exercise = group.exercise
            if exercise.modelContext == nil {
                modelContext.insert(exercise)
            }
            for (index, setEntry) in group.sets.enumerated() {
                let workoutSet = WorkoutSet(
                    exercise: exercise,
                    setNumber: index + 1,
                    reps: Int(setEntry.reps),
                    weight: Double(setEntry.weight),
                    rpe: Double(setEntry.rpe),
                    notes: setEntry.notes
                )
                if workout.sets != nil { workout.sets!.append(workoutSet) } else { workout.sets = [workoutSet] }
                modelContext.insert(workoutSet)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save workout: \(error)")
        }

        // Write to Apple Health after local save succeeds.
        // requestAuthorization() is a no-op if permission was already granted;
        // first-time users see the HK system sheet. If they deny, we skip silently.
        Task {
            let hk = HealthKitManager.shared
            guard hk.isAvailable else { return }
            _ = await hk.requestAuthorization()
            await hk.saveWorkoutToHealth(startDate: workoutStartDate, endDate: workoutEndDate)
        }

        viewModel.fetchWorkouts()
        dismiss()
    }
}
