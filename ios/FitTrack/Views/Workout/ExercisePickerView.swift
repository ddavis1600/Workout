import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var exercises: [Exercise] = []
    @State private var showingNewExercise = false
    // AUDIT H5: Exercise.workoutSets is .nullify (per cascade audit),
    // so deleting an exercise leaves historical sets with their name
    // intact. Still confirm — exercises are picked into many workouts
    // and an accidental swipe-delete of "Bench Press" is a hassle to
    // re-pick everywhere.
    @State private var exercisePendingDelete: Exercise? = nil

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(group: String, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup.capitalized }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (group: $0.key, exercises: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                List {
                    ForEach(groupedExercises, id: \.group) { section in
                        Section {
                            ForEach(section.exercises, id: \.self) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.ink)
                                            if let equipment = exercise.equipment {
                                                Text(equipment.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.slateText)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Color.emerald)
                                    }
                                }
                                .listRowBackground(Color.slateCard)
                                // Swipe-to-delete user-added exercises. System
                                // seed exercises show the swipe too — but
                                // deleting a widely-used one is rare and
                                // re-creatable via the New Exercise button.
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        exercisePendingDelete = exercise
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(section.group)
                                .foregroundStyle(Color.emerald)
                        }
                    }
                }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search exercises")
                .overlay(alignment: .bottom) {
                    // Floating "New Exercise" CTA always in view. When the
                    // user searches for something that doesn't exist in the
                    // library, the label changes to suggest creating it,
                    // passing the search text as the default name.
                    newExerciseButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewExercise = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingNewExercise) {
                NewExerciseSheet(defaultName: searchText) { newExercise in
                    modelContext.insert(newExercise)
                    try? modelContext.save()
                    // Refresh + auto-select the just-created exercise so
                    // the user goes straight back into their workout flow.
                    fetchExercises()
                    onSelect(newExercise)
                    dismiss()
                }
            }
            .confirmationDialog(
                exercisePendingDelete.map { "Delete \"\($0.name)\"?" } ?? "Delete exercise?",
                isPresented: Binding(
                    get: { exercisePendingDelete != nil },
                    set: { if !$0 { exercisePendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let e = exercisePendingDelete {
                        deleteExercise(e)
                    }
                    exercisePendingDelete = nil
                }
                Button("Cancel", role: .cancel) { exercisePendingDelete = nil }
            } message: {
                Text("Removes this exercise from the picker. Past workouts that used it keep their data.")
            }
            .onAppear {
                fetchExercises()
            }
        }
    }

    // MARK: - New Exercise CTA

    @ViewBuilder
    private var newExerciseButton: some View {
        Button {
            showingNewExercise = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                Text(filteredExercises.isEmpty && !searchText.isEmpty
                     ? "Create \"\(searchText)\""
                     : "New Exercise")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.emerald)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func fetchExercises() {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        exercises = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteExercise(_ exercise: Exercise) {
        // Any WorkoutSets that referenced this exercise will have their
        // `exercise` relationship nullified (per @Relationship deleteRule).
        // Those sets will show "Unknown" in workout history.
        modelContext.delete(exercise)
        try? modelContext.save()
        fetchExercises()
    }
}

// MARK: - New Exercise Sheet

/// Simple form for adding a custom exercise to the user's library. Fields
/// intentionally limited to the schema's three columns (name, muscleGroup,
/// equipment) — matches what the seed data uses, so custom exercises look
/// and behave identically to built-ins.
struct NewExerciseSheet: View {
    let defaultName: String
    let onSave: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var muscleGroup: String = "Chest"
    @State private var equipment: String = "barbell"
    @FocusState private var nameFocused: Bool

    /// Muscle groups already in use across the seed set. Keeping the list
    /// matched to existing values means the new exercise shows up in an
    /// existing section of ExercisePickerView instead of creating a
    /// one-off section.
    private static let muscleGroups: [String] = [
        "Chest", "Back", "Shoulders", "Arms",
        "Legs", "Core", "Cardio", "Other",
    ]

    /// Equipment values matched to seed data (lowercased strings).
    private static let equipmentOptions: [(id: String, label: String, icon: String)] = [
        ("barbell",        "Barbell",         "dumbbell.fill"),
        ("dumbbell",       "Dumbbell",        "dumbbell"),
        ("machine",        "Machine",         "gearshape.2.fill"),
        ("cable",          "Cable",           "cable.connector"),
        ("bodyweight",     "Bodyweight",      "figure.strengthtraining.functional"),
        ("kettlebell",     "Kettlebell",      "circle.hexagonpath.fill"),
        ("resistance-band","Resistance Band", "waveform.path"),
        ("other",          "Other",           "ellipsis.circle"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                Form {
                    Section {
                        TextField("e.g. Bulgarian Split Squat", text: $name)
                            .focused($nameFocused)
                            .foregroundStyle(Color.ink)
                    } header: {
                        Text("Name").foregroundStyle(Color.slateText)
                    }
                    .listRowBackground(Color.slateCard)

                    Section {
                        Picker("Muscle Group", selection: $muscleGroup) {
                            ForEach(Self.muscleGroups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                    } header: {
                        Text("Muscle Group").foregroundStyle(Color.slateText)
                    }
                    .listRowBackground(Color.slateCard)

                    Section {
                        Picker("Equipment", selection: $equipment) {
                            ForEach(Self.equipmentOptions, id: \.id) { opt in
                                Label(opt.label, systemImage: opt.icon).tag(opt.id)
                            }
                        }
                        .tint(.emerald)
                        .foregroundStyle(Color.ink)
                    } header: {
                        Text("Equipment").foregroundStyle(Color.slateText)
                    }
                    .listRowBackground(Color.slateCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Exercise")
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
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = defaultName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Defer focus so the keyboard animates in after the sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    nameFocused = true
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let exercise = Exercise(
            name: trimmedName,
            muscleGroup: muscleGroup,
            equipment: equipment.isEmpty ? nil : equipment
        )
        onSave(exercise)
        dismiss()
    }
}
