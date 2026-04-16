import SwiftUI
import SwiftData
import PhotosUI

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

    // MARK: - Meal sheet / picker state (owned here so a single .sheet drives all meal rows)

    private enum MealSheet: Identifiable {
        case foodSearch(String)   // meal type
        case camera(String)       // meal type
        var id: String {
            switch self {
            case .foodSearch(let m): return "food_\(m)"
            case .camera(let m):    return "cam_\(m)"
            }
        }
    }

    @State private var mealSheet: MealSheet? = nil
    @State private var libraryPickerMeal: String? = nil
    @State private var libraryPickerItem: PhotosPickerItem? = nil
    // Token per meal: MealSectionView reloads its photo whenever this UUID changes
    @State private var mealPhotoTokens: [String: UUID] = [:]

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
            // Single sheet at NavigationStack level — avoids conflicts from multiple
            // .sheet modifiers on sibling List rows (which only the last one would fire).
            .sheet(item: $mealSheet) { sheet in
                switch sheet {
                case .foodSearch(let mealType):
                    if let vm = viewModel {
                        FoodSearchView { food, servings in
                            vm.addEntry(food: food, mealType: mealType, servings: servings)
                        }
                    }
                case .camera(let mealType):
                    MealCameraView { image in
                        saveMealPhoto(mealType: mealType, image: image)
                    }
                }
            }
            .photosPicker(
                isPresented: Binding(
                    get: { libraryPickerMeal != nil },
                    set: { if !$0 { libraryPickerMeal = nil } }
                ),
                selection: $libraryPickerItem,
                matching: .images
            )
            .onChange(of: libraryPickerItem) { _, newItem in
                Task {
                    guard let meal = libraryPickerMeal,
                          let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    saveMealPhoto(mealType: meal, image: uiImage)
                    libraryPickerItem = nil
                    libraryPickerMeal = nil
                }
            }
        }
    }

    // MARK: - Meal photo helpers

    private func mealPhotoKey(mealType: String) -> String {
        let date = viewModel?.selectedDate ?? Date()
        return "meal_photo_\(mealType)_\(date.formatted(as: "yyyy-MM-dd")).jpg"
    }

    private func saveMealPhoto(mealType: String, image: UIImage) {
        let key = mealPhotoKey(mealType: mealType)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let jpeg = image.jpegData(compressionQuality: 0.75) {
            try? jpeg.write(to: dir.appendingPathComponent(key))
        }
        mealPhotoTokens[mealType] = UUID()
    }

    private func deleteMealPhoto(mealType: String) {
        let key = mealPhotoKey(mealType: mealType)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealPhotos")
            .appendingPathComponent(key)
        try? FileManager.default.removeItem(at: url)
        mealPhotoTokens[mealType] = UUID()
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

    /// UserDefaults key for the water count on the currently viewed date.
    /// UserDefaults is the source of truth so counts persist across navigation;
    /// HealthKit is synced as a bonus when the user is on today's date.
    private var waterDefaultsKey: String {
        let date = viewModel?.selectedDate ?? Date()
        return "water_glasses_\(date.formatted(as: "yyyy-MM-dd"))"
    }

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
                    guard waterGlasses > 0 else { return }
                    waterGlasses -= 1
                    UserDefaults.standard.set(waterGlasses, forKey: waterDefaultsKey)
                    let selectedDate = viewModel?.selectedDate ?? Date()
                    if Calendar.current.isDateInToday(selectedDate) {
                        Task {
                            await HealthKitManager.shared.deleteLatestWater(date: Date())
                        }
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
                    UserDefaults.standard.set(waterGlasses, forKey: waterDefaultsKey)
                    let selectedDate = viewModel?.selectedDate ?? Date()
                    if Calendar.current.isDateInToday(selectedDate) {
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
                    },
                    onAddFoodTapped: {
                        mealSheet = .foodSearch(mealType)
                    },
                    onCameraTapped: {
                        // Small delay lets the confirmationDialog finish dismissing
                        // before the camera sheet presents from the NavigationStack level.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            mealSheet = .camera(mealType)
                        }
                    },
                    onLibraryTapped: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            libraryPickerMeal = mealType
                        }
                    },
                    onDeletePhoto: {
                        deleteMealPhoto(mealType: mealType)
                    },
                    photoLoadToken: mealPhotoTokens[mealType] ?? UUID()
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
        // Load from UserDefaults immediately — works for any date, no async wait.
        let local = UserDefaults.standard.integer(forKey: waterDefaultsKey)
        waterGlasses = local

        // For today only, try to reconcile with HealthKit (in case another app logged water).
        let selectedDate = viewModel?.selectedDate ?? Date()
        guard Calendar.current.isDateInToday(selectedDate) else { return }

        let totalML = await HealthKitManager.shared.fetchWaterToday()
        let hkGlasses = Int(totalML / mlPerGlass)
        if hkGlasses > 0 && hkGlasses != local {
            waterGlasses = hkGlasses
            UserDefaults.standard.set(hkGlasses, forKey: waterDefaultsKey)
        }
    }
}
