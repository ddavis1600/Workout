import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onAdd: (Food, Double) -> Void

    @State private var searchText = ""
    @State private var foods: [Food] = []
    @State private var selectedFood: Food?
    @State private var servings: Double = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                List {
                    ForEach(filteredFoods, id: \.self) { food in
                        foodRow(food)
                            .listRowBackground(Color.slateCard)
                    }
                }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search foods")
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.slateText)
                }
            }
            .onAppear {
                fetchAllFoods()
            }
        }
    }

    // MARK: - Filtered Foods

    private var filteredFoods: [Food] {
        if searchText.isEmpty {
            return foods
        }
        return foods.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Food Row

    private func foodRow(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedFood === food {
                        selectedFood = nil
                    } else {
                        selectedFood = food
                        servings = 1.0
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            if let brand = food.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(Color.slateText)
                            }
                            Text("\(Int(food.calories)) kcal")
                                .font(.caption)
                                .foregroundStyle(Color.emerald)
                            Text("\(food.servingSize, specifier: "%.0f") \(food.servingUnit)")
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                    }
                    Spacer()
                    Image(systemName: selectedFood === food ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
            }

            if selectedFood === food {
                expandedDetails(food)
            }
        }
    }

    // MARK: - Expanded Details

    private func expandedDetails(_ food: Food) -> some View {
        VStack(spacing: 12) {
            Divider()
                .overlay(Color.slateBorder)

            // Macros
            HStack(spacing: 16) {
                macroLabel("Protein", value: food.protein * servings, unit: "g", color: .blue)
                macroLabel("Carbs", value: food.carbs * servings, unit: "g", color: .orange)
                macroLabel("Fat", value: food.fat * servings, unit: "g", color: .pink)
            }

            // Servings
            HStack {
                Text("Servings")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    if servings > 0.5 {
                        servings -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.slateText)
                }

                Text("\(servings, specifier: "%.1f")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, alignment: .center)

                Button {
                    servings += 0.5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.emerald)
                }
            }

            // Total calories
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .foregroundStyle(Color.slateText)
                Spacer()
                Text("\(Int(food.calories * servings)) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            // Add button
            Button {
                onAdd(food, servings)
                dismiss()
            } label: {
                Text("Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 8)
    }

    private func macroLabel(_ label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))\(unit)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.slateText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func fetchAllFoods() {
        let descriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
        foods = (try? modelContext.fetch(descriptor)) ?? []
    }
}
