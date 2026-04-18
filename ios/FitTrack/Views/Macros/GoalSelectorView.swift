import SwiftUI

struct GoalSelectorView: View {
    @Binding var selectedGoal: String

    private struct GoalOption {
        let key: String
        let title: String
        let adjustment: String
        let description: String
    }

    private let goals: [GoalOption] = [
        GoalOption(key: "cut", title: "Cut", adjustment: "-500 kcal", description: "Lose fat while preserving muscle"),
        GoalOption(key: "maintain", title: "Maintain", adjustment: "+0 kcal", description: "Stay at your current weight"),
        GoalOption(key: "bulk", title: "Bulk", adjustment: "+300 kcal", description: "Build muscle with lean gains"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal")
                .font(.headline)
                .foregroundStyle(Color.ink)

            HStack(spacing: 10) {
                ForEach(goals, id: \.key) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: GoalOption) -> some View {
        let isSelected = selectedGoal == goal.key

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGoal = goal.key
            }
        } label: {
            VStack(spacing: 6) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.paper : Color.slateText)

                Text(goal.adjustment)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Color.emerald : Color.slateText)

                Text(goal.description)
                    .font(.caption2)
                    .foregroundStyle(Color.slateText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(isSelected ? Color.emerald.opacity(0.15) : Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.emerald : Color.slateBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
