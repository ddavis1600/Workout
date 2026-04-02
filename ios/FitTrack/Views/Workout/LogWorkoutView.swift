import SwiftUI
import SwiftData

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var viewModel: WorkoutViewModel

    @State private var workoutName = ""
    @State private var workoutDate = Date.now
    @State private var workoutNotes = ""
    @State private var exerciseGroups: [ExerciseGroup] = []
    @State private var showingExercisePicker = false

    struct SetEntry: Identifiable {
        let id = UUID()
        var reps: String
        var weight: String
        var rpe: String
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
                        workoutInfoSection
                        exerciseSections
                        addExerciseButton
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
        }
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

    // MARK: - Save

    private func saveWorkout() {
        let workout = Workout(
            name: workoutName,
            date: workoutDate,
            notes: workoutNotes
        )

        modelContext.insert(workout)

        for group in exerciseGroups {
            for (index, setEntry) in group.sets.enumerated() {
                let workoutSet = WorkoutSet(
                    exercise: group.exercise,
                    setNumber: index + 1,
                    reps: Int(setEntry.reps),
                    weight: Double(setEntry.weight),
                    rpe: Double(setEntry.rpe)
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
