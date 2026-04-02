import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var exercises: [Exercise] = []

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
                                                .foregroundStyle(.white)
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
            }
            .onAppear {
                fetchExercises()
            }
        }
    }

    private func fetchExercises() {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        exercises = (try? modelContext.fetch(descriptor)) ?? []
    }
}
