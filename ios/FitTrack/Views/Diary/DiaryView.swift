import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var viewModel: DiaryViewModel?

    // Water logging
    @State private var waterGlasses: Int = 0
    @State private var isLoadingWater = false
    private let mlPerGlass: Double = 250

    // Net carbs toggle
    @AppStorage("showNetCarbs") private var showNetCarbs = false

    private var profile: UserProfile? {
        profiles.first
    }

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        NavigationStack {
            List {
                datePicker
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                summarySection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                waterSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                mealSections
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Food Diary")
            .task {
                if viewModel == nil {
                    viewModel = DiaryViewModel(modelContext: modelContext)
                } else {
                    viewModel?.fetchEntries()
                }
                await fetchWaterCount()
            }
        }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        HStack {
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.emerald)
                    .padding(8)
            }

            Spacer()

            if let vm = viewModel {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { vm.selectedDate },
                        set: { newDate in
                            vm.selectedDate = newDate.startOfDay
                            vm.fetchEntries()
                            Task { await fetchWaterCount() }
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.emerald)
            }

            Spacer()

            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.emerald)
                    .padding(8)
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

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Summary")
                .font(.headline)
                .foregroundStyle(.white)

            if let vm = viewModel {
                let calorieTarget = profile?.calorieTarget ?? 2000
                let proteinTarget = profile?.proteinTarget ?? 150
                let carbTarget = profile?.carbTarget ?? 200
                let fatTarget = profile?.fatTarget ?? 65

                MacroProgressBar(label: "Calories", current: vm.totalCalories, target: calorieTarget, unit: "kcal", color: .emerald)
                MacroProgressBar(label: "Protein", current: vm.totalProtein, target: proteinTarget, unit: "g", color: .blue)
                MacroProgressBar(
                    label: showNetCarbs ? "Net Carbs" : "Carbs",
                    current: showNetCarbs ? vm.totalNetCarbs : vm.totalCarbs,
                    target: carbTarget,
                    unit: "g",
                    color: .orange
                )
                MacroProgressBar(label: "Fat", current: vm.totalFat, target: fatTarget, unit: "g", color: .pink)
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

    // MARK: - Water Section

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.blue)
                Text("Water")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(Double(waterGlasses) * mlPerGlass)) mL")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.blue)
            }

            HStack(spacing: 12) {
                // Glass icons
                let maxDisplay = 8
                ForEach(0..<maxDisplay, id: \.self) { i in
                    Image(systemName: i < waterGlasses ? "drop.fill" : "drop")
                        .font(.title3)
                        .foregroundStyle(i < waterGlasses ? Color.blue : Color.slateBorder)
                }
                if waterGlasses > maxDisplay {
                    Text("+\(waterGlasses - maxDisplay)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.blue)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    if waterGlasses > 0 {
                        waterGlasses -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(waterGlasses > 0 ? Color.slateText : Color.slateBorder)
                }
                .disabled(waterGlasses == 0)

                Text("\(waterGlasses) glass\(waterGlasses == 1 ? "" : "es")")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(minWidth: 80)

                Button {
                    waterGlasses += 1
                    if Calendar.current.isDateInToday(viewModel?.selectedDate ?? Date()) {
                        Task {
                            await HealthKitManager.shared.saveWater(ml: mlPerGlass, date: Date())
                        }
                    }
                } label: {
                    Label("+1 glass", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    // MARK: - Meal Sections

    private var mealSections: some View {
        ForEach(mealTypes, id: \.self) { mealType in
            if let vm = viewModel {
                let mealEntries = vm.entriesByMeal[mealType] ?? []
                MealSectionView(
                    mealType: mealType,
                    entries: mealEntries,
                    date: vm.selectedDate,
                    onAdd: { food, servings in
                        vm.addEntry(food: food, mealType: mealType, servings: servings)
                    },
                    onDelete: { entry in
                        vm.deleteEntry(entry)
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func changeDate(by days: Int) {
        guard let vm = viewModel else { return }
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: vm.selectedDate) {
            vm.selectedDate = newDate.startOfDay
            vm.fetchEntries()
            Task { await fetchWaterCount() }
        }
    }

    private func fetchWaterCount() async {
        let totalML = await HealthKitManager.shared.fetchWaterToday()
        waterGlasses = Int(totalML / mlPerGlass)
    }
}
