import SwiftUI
import SwiftData

struct RecentWorkoutsCard: View {
    let workout: Workout

    private var displayName: String {
        workout.name.isEmpty ? "Workout" : workout.name
    }

    private var exerciseCount: Int {
        Set(workout.sets.compactMap { $0.exercise?.name }).count
    }

    private var setCount: Int {
        workout.sets.count
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.emerald)
                .frame(width: 4, height: 44)

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
