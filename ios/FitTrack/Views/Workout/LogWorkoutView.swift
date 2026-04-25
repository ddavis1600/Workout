import SwiftUI
import SwiftData
import Combine
import PhotosUI
import WatchConnectivity

/// Full-screen workout logger. All session state lives on
/// `WorkoutSessionManager.shared` so it survives minimize/expand cycles
/// (see the mini bar in ContentView).
struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var session = WorkoutSessionManager.shared
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @Query private var userProfiles: [UserProfile]
    private var unitSystem: String { userProfiles.first?.unitSystem ?? "imperial" }
    private var distanceUnitLabel: String { unitSystem == "imperial" ? "mi" : "km" }

    // Transient view state (not worth persisting across minimize):
    @State private var showingExercisePicker = false
    @State private var showingSaveTemplate = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var timerTick = Date()   // forces a re-render every second
    @State private var hasLoadedTemplate = false

    // Rest timer (UI-only, lives here)
    @AppStorage("restTimerSeconds") private var restTimerDuration = 60
    @AppStorage("restTimerEnabled") private var restTimerEnabled = true
    @State private var showRestTimer = false

    private var userAge: Int {
        let age = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        return age > 0 ? age : 25
    }

    /// Formats the live GPS distance for the on-screen indicator.
    private func formatLiveDistance() -> String {
        let m = session.liveDistanceMeters
        if unitSystem == "imperial" {
            return String(format: "%.2f mi", m * 0.000621371)
        }
        return String(format: "%.2f km", m / 1000.0)
    }

    /// Formats the live elevation gain for the on-screen indicator.
    private func formatLiveElevation() -> String {
        let m = session.liveElevationGain
        if unitSystem == "imperial" {
            return "\(Int((m * 3.28084).rounded())) ft"
        }
        return "\(Int(m.rounded())) m"
    }

    /// Workout type picker options. Kept here (not in the model) so the UI
    /// presentation labels can be changed without a schema migration.
    private static let workoutTypeOptions: [(id: String, label: String, icon: String)] = [
        ("strength",  "Strength",     "dumbbell.fill"),
        ("running",   "Running",      "figure.run"),
        ("cycling",   "Cycling",      "bicycle"),
        ("walking",   "Walking",      "figure.walk"),
        ("hiit",      "HIIT",         "flame.fill"),
        ("yoga",      "Yoga",         "figure.mind.and.body"),
        ("swimming",  "Swimming",     "figure.pool.swim"),
        ("other",     "Other",        "figure.flexibility"),
    ]

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
                        WorkoutHeartRateCard(service: session.heartRateService, userAge: userAge)
                        workoutInfoSection
                        photoSection
                        exerciseSections
                        addExerciseButton
                        if !session.exerciseGroups.isEmpty {
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
                    Button {
                        // Cancel: stop the session and dismiss.
                        WatchConnectivityManager.shared.sendStopWorkout()
                        session.end()
                    } label: {
                        Text("Cancel")
                            .foregroundStyle(Color.slateText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    // Minimize button — keeps the workout running behind the tab bar.
                    Button {
                        session.minimize()
                    } label: {
                        Label("Minimize", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(Color.slateText)
                    }
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
                    let initialSet = SetEntry()
                    session.exerciseGroups.append(ExerciseGroup(exercise: exercise, sets: [initialSet]))
                }
            }
            .sheet(isPresented: $showingSaveTemplate) {
                SaveTemplateSheet(exerciseGroups: session.exerciseGroups.map { group in
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
                loadTemplateIfNeeded()
            }
            // Cheap re-render ticker for the elapsed-time display.
            // Does NOT drive the clock — `session.elapsedSeconds` is always
            // computed from startDate — this just tells SwiftUI to recompute.
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
                timerTick = now
            }
            // watchManager.pendingWorkoutStop is now handled globally in
            // ContentView so that watch-initiated stops save even when this
            // view isn't mounted (minimized / different tab).
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    // Off-main downscale + JPEG encode (audit M2). Was
                    // `UIImage(data:).jpegData(...)` on the main actor —
                    // 80–200 ms hitch on a 12 MP capture, visible as
                    // PhotosPicker-dismiss jank.
                    session.selectedPhotoData = await ImageCompression.compressedJPEG(from: data) ?? data
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

    private var timerSection: some View {
        VStack(spacing: 10) {
            Text(formattedElapsedTime)
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.emerald)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 20) {
                Button {
                    if session.isPaused {
                        session.resume()
                    } else {
                        session.pause()
                    }
                } label: {
                    Label(session.isPaused ? "Resume" : "Pause",
                          systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.emerald)
                }

                Button {
                    session.resetTimer()
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

    private var formattedElapsedTime: String {
        // `timerTick` is referenced to force a re-render each second.
        _ = timerTick
        let seconds = session.elapsedSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, sec)
    }

    // MARK: - Workout Info

    private var workoutInfoSection: some View {
        VStack(spacing: 14) {
            TextField("Workout Name (optional)", text: $session.workoutName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)

            // Workout type picker (item 10) — maps to HKWorkoutActivityType on save.
            HStack {
                Text("Type")
                    .font(.subheadline)
                    .foregroundStyle(Color.slateText)
                Spacer()
                Picker("Type", selection: $session.workoutType) {
                    ForEach(Self.workoutTypeOptions, id: \.id) { option in
                        Label(option.label, systemImage: option.icon)
                            .tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.emerald)
            }
            .padding(12)
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Distance field — only relevant for running / cycling / walking / swimming.
            // Stored in meters on the model; user types in mi or km based on their
            // unit preference. When the Watch is live-tracking GPS, the captured
            // distance appears here as a read-only row that overrides any manual
            // input at save time.
            if Workout.isDistanceType(session.workoutType) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Distance")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                        Spacer()
                        TextField("0.0", text: $session.distanceInput)
                            .textFieldStyle(.plain)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .foregroundStyle(Color.ink)
                            .disabled(session.liveDistanceMeters > 0)
                        Text(distanceUnitLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.slateText)
                            .frame(width: 24, alignment: .leading)
                    }
                    if session.liveDistanceMeters > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.emerald)
                            Text("GPS: \(formatLiveDistance())")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.emerald)
                            if session.liveElevationGain > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(Color.slateText)
                                Image(systemName: "mountain.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.emerald)
                                Text(formatLiveElevation())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.emerald)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            DatePicker("Date", selection: $session.workoutDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.emerald)
                .foregroundStyle(Color.ink)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            TextField("Notes (optional)", text: $session.workoutNotes, axis: .vertical)
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

            if let photoData = session.selectedPhotoData, let uiImage = UIImage(data: photoData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        session.selectedPhotoData = nil
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
                Label(session.selectedPhotoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
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
        }
    }

    // MARK: - Exercise Sections

    private var exerciseSections: some View {
        ForEach($session.exerciseGroups) { $group in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(group.exercise.name)
                        .font(.headline)
                        .foregroundStyle(Color.emerald)
                    Spacer()
                    Button {
                        withAnimation {
                            session.exerciseGroups.removeAll { $0.id == group.id }
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

    private func loadTemplateIfNeeded() {
        guard !hasLoadedTemplate else { return }
        hasLoadedTemplate = true
        guard let template = session.pendingTemplate, session.exerciseGroups.isEmpty else { return }

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
            session.exerciseGroups.append(ExerciseGroup(exercise: exercise, sets: sets))
        }

        // Consume the template so it doesn't reload on minimize/expand.
        session.pendingTemplate = nil
    }

    // MARK: - Save

    /// Delegate to the shared WorkoutPersistence helper so the watch-stop
    /// auto-save path in ContentView and the phone Save-button path here
    /// run the exact same flow (including the brief wait for the watch's
    /// final GPS payload).
    private func saveWorkout() {
        Task {
            await WorkoutPersistence.saveAndEnd(context: modelContext, unitSystem: unitSystem)
        }
    }
}
