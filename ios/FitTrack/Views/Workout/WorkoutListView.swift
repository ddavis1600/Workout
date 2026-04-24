import SwiftUI
import SwiftData
import WatchConnectivity

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkoutViewModel?
    @State private var showingLogWorkout = false
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @State private var showingTemplates = false
    @State private var showingPRHistory = false
    @State private var showingProgress = false
    @State private var showingManualWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var pendingDelete: Workout?

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
                        .accessibilityLabel("Workout templates")
                        Button {
                            showingPRHistory = true
                        } label: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                        .accessibilityLabel("Personal records")
                        Button {
                            showingProgress = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Color.emerald)
                        }
                        .accessibilityLabel("Progress charts")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Menu instead of bare + — two clear entry paths:
                    //   Log Workout: live timer flow (LogWorkoutView in
                    //     the new "Ready" state from #2)
                    //   Add Workout (no timer): backdated manual entry,
                    //     new in this branch, skips timer + HK write
                    Menu {
                        Button {
                            selectedTemplate = nil
                            showingLogWorkout = true
                        } label: {
                            Label("Log Workout", systemImage: "timer")
                        }
                        Button {
                            showingManualWorkout = true
                        } label: {
                            Label("Add Workout (no timer)", systemImage: "calendar.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                    .accessibilityLabel("New workout")
                }
            }
            .sheet(isPresented: $showingLogWorkout, onDismiss: {
                viewModel?.fetchWorkouts()
            }) {
                if let vm = viewModel {
                    LogWorkoutView(viewModel: vm, template: selectedTemplate)
                }
            }
            .sheet(isPresented: $showingTemplates) {
                TemplateListView { template in
                    selectedTemplate = template
                    showingLogWorkout = true
                }
            }
            .sheet(isPresented: $showingManualWorkout) {
                ManualWorkoutView(onSave: {
                    viewModel?.fetchWorkouts()
                })
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
            .onChange(of: watchManager.pendingWorkoutStart) { _, newValue in
                if newValue && viewModel != nil {
                    selectedTemplate = nil
                    showingLogWorkout = true
                    watchManager.pendingWorkoutStart = false
                }
            }
            .confirmDestructive(
                item: $pendingDelete,
                title: "Delete workout?",
                message: { workout in
                    let displayName = workout.name.isEmpty ? "this workout" : "“\(workout.name)”"
                    let setCount = (workout.sets ?? []).count
                    let setStr = setCount == 1 ? "1 set" : "\(setCount) sets"
                    return "Removes \(displayName) (\(setStr)). This can't be undone."
                }
            ) { workout in
                viewModel?.deleteWorkout(workout)
            }
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
                        pendingDelete = workout
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
