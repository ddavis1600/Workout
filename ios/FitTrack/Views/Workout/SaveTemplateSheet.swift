import SwiftUI
import SwiftData

struct SaveTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exerciseGroups: [(exerciseName: String, muscleGroup: String, setCount: Int, reps: String, weight: String)]

    @State private var templateName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField("Template Name", text: $templateName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.slateCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Color.ink)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exercises")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.slateText)

                        ForEach(Array(exerciseGroups.enumerated()), id: \.offset) { _, group in
                            HStack {
                                Text(group.exerciseName)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ink)
                                Spacer()
                                Text("\(group.setCount) sets")
                                    .font(.caption)
                                    .foregroundStyle(Color.emerald)
                            }
                            .padding(10)
                            .background(Color.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Save Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveTemplate() }
                        .foregroundStyle(Color.emerald)
                        .fontWeight(.semibold)
                        .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveTemplate() {
        let template = WorkoutTemplate(name: templateName)
        modelContext.insert(template)

        for (index, group) in exerciseGroups.enumerated() {
            let te = TemplateExercise(
                exerciseName: group.exerciseName,
                muscleGroup: group.muscleGroup,
                defaultSets: group.setCount,
                defaultReps: Int(group.reps) ?? 10,
                defaultWeight: Double(group.weight) ?? 0,
                sortOrder: index
            )
            te.template = template
            template.exercises.append(te)
            modelContext.insert(te)
        }

        try? modelContext.save()
        dismiss()
    }
}
