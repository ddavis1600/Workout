import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkoutViewModel?
    @State private var showingLogWorkout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                if let vm = viewModel {
                    if vm.workouts.isEmpty {
                        emptyState
                    } else {
                        workoutList(vm: vm)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingLogWorkout) {
                if let vm = viewModel {
                    LogWorkoutView(viewModel: vm)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = WorkoutViewModel(modelContext: modelContext)
                }
                viewModel?.fetchWorkouts()
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
                .foregroundStyle(.white)
            Text("Tap the + button to log your first workout.")
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Workout List

    private func workoutList(vm: WorkoutViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.workouts, id: \.self) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        workoutRow(workout)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            vm.deleteWorkout(workout)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        let displayName = workout.name.isEmpty ? "Workout" : workout.name
        let exerciseCount = Set(workout.sets.compactMap { $0.exercise?.name }).count
        let setCount = workout.sets.count

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.emerald)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
