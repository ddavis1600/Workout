import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout

    private var displayName: String {
        workout.name.isEmpty ? "Workout" : workout.name
    }

    private var exerciseGroups: [(exercise: String, sets: [WorkoutSet])] {
        var groups: [String: [WorkoutSet]] = [:]
        var order: [String] = []

        for set in workout.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
            let name = set.exercise?.name ?? "Unknown"
            if groups[name] == nil {
                order.append(name)
                groups[name] = []
            }
            groups[name]?.append(set)
        }

        return order.map { (exercise: $0, sets: groups[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let photoData = workout.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    headerSection
                    exerciseSections
                }
                .padding()
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                StatCard(
                    icon: "calendar",
                    title: "Date",
                    value: workout.date.formatted(as: "MMM d, yyyy")
                )
            }

            if let duration = workout.durationMinutes, duration > 0 {
                StatCard(
                    icon: "clock",
                    title: "Duration",
                    value: "\(duration) min"
                )
            }

            if !workout.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                    Text(workout.notes)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Exercise Sections

    private var exerciseSections: some View {
        ForEach(exerciseGroups, id: \.exercise) { group in
            VStack(alignment: .leading, spacing: 10) {
                Text(group.exercise)
                    .font(.headline)
                    .foregroundStyle(Color.emerald)

                // Table header
                HStack {
                    Text("Set")
                        .frame(width: 36, alignment: .leading)
                    Text("Reps")
                        .frame(width: 50, alignment: .center)
                    Text("Weight")
                        .frame(width: 70, alignment: .center)
                    Text("RPE")
                        .frame(width: 40, alignment: .center)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.slateText)
                .padding(.horizontal, 4)

                Divider()
                    .overlay(Color.slateBorder)

                ForEach(group.sets, id: \.self) { workoutSet in
                    HStack {
                        Text("#\(workoutSet.setNumber)")
                            .frame(width: 36, alignment: .leading)
                        Text(workoutSet.reps != nil ? "\(workoutSet.reps!)" : "-")
                            .frame(width: 50, alignment: .center)
                        Text(workoutSet.weight != nil ? "\(workoutSet.weight!, specifier: "%.1f")" : "-")
                            .frame(width: 70, alignment: .center)
                        Text(workoutSet.rpe != nil ? "\(workoutSet.rpe!, specifier: "%.1f")" : "-")
                            .frame(width: 40, alignment: .center)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
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
}
