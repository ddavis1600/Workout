import SwiftUI
import SwiftData

struct MealSectionView: View {
    let mealType: String
    let entries: [DiaryEntry]
    var onAdd: (Food, Double) -> Void
    var onDelete: (DiaryEntry) -> Void

    @State private var showingFoodSearch = false

    private var mealCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(mealType.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(mealCalories)) kcal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
            }

            if entries.isEmpty {
                Text("No food logged")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .padding(.vertical, 4)
            } else {
                ForEach(entries, id: \.self) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.food?.name ?? "Unknown")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text("\(entry.servings, specifier: "%.1f") serving\(entry.servings == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                        Spacer()
                        Text("\(Int(entry.totalCalories)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Divider()
                .overlay(Color.slateBorder)

            Button {
                showingFoodSearch = true
            } label: {
                Label("Add Food", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView { food, servings in
                    onAdd(food, servings)
                }
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
