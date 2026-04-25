import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]

    var onSelect: (WorkoutTemplate) -> Void

    // AUDIT H5: per-row delete confirmation. WorkoutTemplate.exercises
    // is .cascade — accidental swipe destroys every TemplateExercise
    // configured for that template. Worth a confirm.
    @State private var templatePendingDelete: WorkoutTemplate? = nil

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
                            .foregroundStyle(Color.ink)
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
                                        .foregroundStyle(Color.ink)
                                    let exerciseNames = (template.exercises ?? [])
                                        .sorted { $0.sortOrder < $1.sortOrder }
                                        .map(\.exerciseName)
                                        .joined(separator: ", ")
                                    Text(exerciseNames)
                                        .font(.caption)
                                        .foregroundStyle(Color.slateText)
                                        .lineLimit(2)
                                    Text("\((template.exercises ?? []).count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(Color.emerald)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.slateCard)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    templatePendingDelete = template
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
            .confirmationDialog(
                templatePendingDelete.map { "Delete \"\($0.name)\"?" } ?? "Delete template?",
                isPresented: Binding(
                    get: { templatePendingDelete != nil },
                    set: { if !$0 { templatePendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let t = templatePendingDelete {
                        modelContext.delete(t)
                        try? modelContext.save()
                    }
                    templatePendingDelete = nil
                }
                Button("Cancel", role: .cancel) { templatePendingDelete = nil }
            } message: {
                if let t = templatePendingDelete {
                    let count = (t.exercises ?? []).count
                    Text(count == 0
                         ? "This can't be undone."
                         : "Removes the template and its \(count) exercise\(count == 1 ? "" : "s").")
                }
            }
        }
    }
}
