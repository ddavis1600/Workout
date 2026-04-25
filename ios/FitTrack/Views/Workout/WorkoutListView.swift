import SwiftUI
import SwiftData
import WatchConnectivity

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkoutViewModel?
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @ObservedObject private var session = WorkoutSessionManager.shared
    @State private var showingTemplates = false
    @State private var showingPRHistory = false
    @State private var showingProgress = false
    // AUDIT H5
    @State private var workoutPendingDelete: Workout? = nil

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.workouts.isEmpty {
                        emptyState
                    } else {
                        workoutList(vm: vm)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.slateBackground)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            showingTemplates = true
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(Color.emerald)
                        }
                        Button {
                            showingPRHistory = true
                        } label: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                        Button {
                            showingProgress = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Color.emerald)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.start()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                }
            }
            // LogWorkoutView is presented globally in ContentView (driven
            // by WorkoutSessionManager). Refresh the local workout list
            // when the session ends so a just-saved workout appears.
            .onChange(of: session.isActive) { _, isActive in
                if !isActive { viewModel?.fetchWorkouts() }
            }
            .sheet(isPresented: $showingTemplates) {
                TemplateListView { template in
                    session.start(template: template)
                }
            }
            .sheet(isPresented: $showingPRHistory) {
                NavigationStack {
                    PRHistoryView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingPRHistory = false }
                                    .foregroundStyle(Color.emerald)
                            }
                        }
                }
            }
            .sheet(isPresented: $showingProgress) {
                NavigationStack {
                    ProgressChartView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingProgress = false }
                                    .foregroundStyle(Color.emerald)
                            }
                        }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = WorkoutViewModel(modelContext: modelContext)
                }
                viewModel?.fetchWorkouts()
            }
            // Watch-triggered workout start is handled globally by ContentView
            // so it works regardless of which tab is currently selected.
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(Color.slateText)
            Text("No workouts yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
            Text("Tap the + button to log your first workout.")
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Workout List

    private func workoutList(vm: WorkoutViewModel) -> some View {
        List {
            ForEach(vm.workouts, id: \.self) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    workoutRow(workout)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        workoutPendingDelete = workout
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.slateBackground)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .confirmationDialog(
            workoutPendingDelete.map { $0.name.isEmpty ? "Delete this workout?" : "Delete \"\($0.name)\"?" } ?? "Delete workout?",
            isPresented: Binding(
                get: { workoutPendingDelete != nil },
                set: { if !$0 { workoutPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let w = workoutPendingDelete {
                    vm.deleteWorkout(w)
                }
                workoutPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { workoutPendingDelete = nil }
        } message: {
            if let w = workoutPendingDelete {
                let setCount = (w.sets ?? []).count
                Text(setCount == 0
                     ? "This can't be undone."
                     : "This permanently removes the workout and its \(setCount) set\(setCount == 1 ? "" : "s").")
            }
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        let displayName = workout.name.isEmpty ? "Workout" : workout.name
        let exerciseCount = Set((workout.sets ?? []).compactMap { $0.exercise?.name }).count
        let setCount = (workout.sets ?? []).count

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.emerald)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(workout.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Label("\(exerciseCount) exercises", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                Label("\(setCount) sets", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.slateText)
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
