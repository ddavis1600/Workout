import SwiftUI

struct MacroTargetsView: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    private var proteinPercent: Int {
        guard calories > 0 else { return 0 }
        return Int((protein * 4.0 / calories) * 100)
    }

    private var carbsPercent: Int {
        guard calories > 0 else { return 0 }
        return Int((carbs * 4.0 / calories) * 100)
    }

    private var fatPercent: Int {
        guard calories > 0 else { return 0 }
        return Int((fat * 9.0 / calories) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Targets")
                .font(.headline)
                .foregroundStyle(.white)

            // Total Calories
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(Int(calories))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.emerald)
                    Text("kcal / day")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                }
                Spacer()
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )

            // Macro cards
            HStack(spacing: 12) {
                macroCard(label: "Protein", grams: protein, percent: proteinPercent, color: .blue, icon: "fish.fill")
                macroCard(label: "Carbs", grams: carbs, percent: carbsPercent, color: .orange, icon: "leaf.fill")
                macroCard(label: "Fat", grams: fat, percent: fatPercent, color: .pink, icon: "drop.fill")
            }
        }
    }

    private func macroCard(label: String, grams: Double, percent: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(Int(grams))g")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.slateText)

            Text("\(percent)%")
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }
}
