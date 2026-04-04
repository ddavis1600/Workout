import SwiftUI
import SwiftData
import Combine
import PhotosUI

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
    @State private var elapsedSeconds: Int = 0
    @State private var timerIsRunning = true
    @State private var timerSubscription: AnyCancellable?

    // Rest timer
    @AppStorage("restTimerSeconds") private var restTimerDuration = 60
    @AppStorage("restTimerEnabled") private var restTimerEnabled = true
    @State private var showRestTimer = false

    // Heart rate
    @State private var heartRateService = HeartRateService()
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
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
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
                    .disabled(exerciseGroups.isEmpty)
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
                startTimer()
                heartRateService.resetSession()
                await heartRateService.startMonitoring()
                loadTemplate()
            }
            .onDisappear {
                stopTimer()
                heartRateService.stopMonitoring()
            }
        }
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
                .foregroundStyle(.white)

            DatePicker("Date", selection: $workoutDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.emerald)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            TextField("Notes (optional)", text: $workoutNotes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
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
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        // Compress to JPEG to save space
                        if let uiImage = UIImage(data: data),
                           let compressed = uiImage.jpegData(compressionQuality: 0.7) {
                            selectedPhotoData = compressed
                        } else {
                            selectedPhotoData = data
                        }
                    }
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

        for te in template.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { ex in
                ex.name == te.exerciseName
            })
            let exercise = (try? modelContext.fetch(descriptor))?.first
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

        let durationMin = max(1, Int(round(Double(elapsedSeconds) / 60.0)))
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
            for (index, setEntry) in group.sets.enumerated() {
                let workoutSet = WorkoutSet(
                    exercise: group.exercise,
                    setNumber: index + 1,
                    reps: Int(setEntry.reps),
                    weight: Double(setEntry.weight),
                    rpe: Double(setEntry.rpe),
                    notes: setEntry.notes
                )
                workoutSet.workout = workout
                workout.sets.append(workoutSet)
                modelContext.insert(workoutSet)
            }
        }

        try? modelContext.save()
        viewModel.fetchWorkouts()
        dismiss()
    }
}
