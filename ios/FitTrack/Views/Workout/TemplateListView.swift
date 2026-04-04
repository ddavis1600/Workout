import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]

    var onSelect: (WorkoutTemplate) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.slateText)
                        Text("No templates yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Save a workout as a template to reuse it later.")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    let exerciseNames = template.exercises
                                        .sorted { $0.sortOrder < $1.sortOrder }
                                        .map(\.exerciseName)
                                        .joined(separator: ", ")
                                    Text(exerciseNames)
                                        .font(.caption)
                                        .foregroundStyle(Color.slateText)
                                        .lineLimit(2)
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(Color.emerald)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.slateCard)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(templates[index])
                            }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
            }
        }
    }
}
