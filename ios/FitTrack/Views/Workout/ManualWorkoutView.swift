import SwiftUI
import SwiftData

/// Create a workout record without actively performing it — backdating an
/// existing session, or pre-building a routine to log after the fact.
///
/// Reuses the same Workout / WorkoutSet schema that LogWorkoutView writes,
/// so manually-added workouts show up identically in the list and in
/// WorkoutDetailView. Deliberately skips the timer, HR monitoring, and
/// HealthKit write — those only make sense for live sessions. If a user
/// wants their manual workout in Apple Health they can add it in Health
/// directly with the correct timestamp.
struct ManualWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: () -> Void = {}

    // MARK: - Form fields
    @State private var workoutName = ""
    @State private var workoutDate: Date = .now
    @State private var durationMinutes: Int = 30
    @State private var workoutNotes = ""
    @State private var exerciseGroups: [ExerciseGroup] = []
    @State private var showingExercisePicker = false

    // Minimal local types mirroring LogWorkoutView's — same shapes so
    // the save path writes identical WorkoutSet rows.
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
                    VStack(alignment: .leading, spacing: 16) {
                        infoCard
                        exerciseSectionsView
                        addExerciseButton
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.emerald)
                        .fontWeight(.semibold)
                        .disabled(exerciseGroups.isEmpty)
                }
            }
            .keyboardDoneToolbar()
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let initialSet = SetEntry(reps: "", weight: "", rpe: "")
                    exerciseGroups.append(ExerciseGroup(exercise: exercise, sets: [initialSet]))
                }
            }
        }
    }

    // MARK: - Sections

    private var infoCard: some View {
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

            HStack {
                Text("Duration")
                    .foregroundStyle(Color.ink)
                Spacer()
                Stepper(value: $durationMinutes, in: 1...600, step: 5) {
                    Text("\(durationMinutes) min")
                        .foregroundStyle(Color.emerald)
                        .monospacedDigit()
                }
                .labelsHidden()
            }
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

    private var exerciseSectionsView: some View {
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
                    .accessibilityLabel("Remove \(group.exercise.name)")
                }

                HStack(spacing: 10) {
                    Text("#").frame(width: 28)
                    Text("Reps").frame(maxWidth: .infinity)
                    Text("Weight").frame(maxWidth: .infinity)
                    Text("RPE").frame(width: 60)
                    Spacer().frame(width: 28)
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
                    withAnimation { group.sets.append(newSet) }
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

    // MARK: - Save

    private func save() {
        // Build the Workout + WorkoutSets using the same shape
        // LogWorkoutView.saveWorkout uses, so detail / list views
        // don't need to distinguish manually-entered rows.
        let workout = Workout(
            name: workoutName,
            date: workoutDate,
            notes: workoutNotes,
            durationMinutes: durationMinutes > 0 ? durationMinutes : nil,
            photoData: nil
        )

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
                modelContext.insert(workoutSet)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("[ManualWorkoutView] save failed: \(error)")
        }

        // Deliberately NOT calling HealthKitManager.saveWorkoutToHealth —
        // backdated manual entries would write bogus timestamps into
        // Apple Health. If the user actually performed this workout and
        // wants it in Health, they should log it there with the correct
        // start/end times.

        onSave()
        dismiss()
    }
}
