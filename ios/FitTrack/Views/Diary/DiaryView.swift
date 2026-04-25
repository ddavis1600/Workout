import SwiftUI
import SwiftData
import PhotosUI

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var viewModel: DiaryViewModel?

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
                hydrationSection
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
                .foregroundStyle(Color.ink)

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

    // MARK: - Hydration (F9)

    /// Cup count for the diary's currently-selected day. Stored in
    /// UserDefaults under a per-day key (e.g. `water_cups_2026-04-25`)
    /// so the count survives app restarts; HK is the eventual source
    /// of truth, but reading from HK on every view render would add
    /// latency for what's essentially an integer counter.
    ///
    /// Each cup logs 240 mL (8 fl oz) to HealthKit via
    /// `HealthKitManager.saveWater(ml:date:)`.
    private func waterKey(for date: Date) -> String {
        "water_cups_\(date.formatted(as: "yyyy-MM-dd"))"
    }

    private func waterCups(for date: Date) -> Int {
        UserDefaults.standard.integer(forKey: waterKey(for: date))
    }

    private var hydrationSection: some View {
        let selectedDate = viewModel?.selectedDate ?? Date.now
        let cups = waterCups(for: selectedDate)
        let goal = 8 // 8 cups ≈ 1.9 L — a common default; future: profile-driven
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("Hydration")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(cups) / \(goal) cups")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }

            // Visual row of 8 droplet glyphs that fill in as cups are
            // logged — gives the user a quick "how much further" cue
            // without parsing the mL number.
            HStack(spacing: 4) {
                ForEach(0..<goal, id: \.self) { i in
                    Image(systemName: i < cups ? "drop.fill" : "drop")
                        .foregroundStyle(i < cups ? .blue : Color.slateText.opacity(0.5))
                        .font(.title3)
                }
                Spacer()
                Button {
                    addCup(for: selectedDate)
                } label: {
                    Label("1 cup", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.blue, in: Capsule())
                }
                .buttonStyle(.plain)
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

    private func addCup(for date: Date) {
        let key = waterKey(for: date)
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
        // Force a re-render — UserDefaults reads in the body don't
        // trigger SwiftUI invalidation by themselves, so we bump the
        // mealPhotoTokens dict (already used as a refresh signal in
        // this view) to nudge the body. Cheap and side-effect-free.
        mealPhotoTokens["__hydration"] = UUID()

        // Side-effect write to Health. The auth gate is V2-aware:
        // first-time tappers get the prompt; everyone else proceeds
        // silently. If the user denies, the local count still
        // increments — HK is mirror, not master.
        let now = Date()
        Task {
            let hk = HealthKitManager.shared
            guard hk.isAvailable, await hk.requestAuthorizationIfNeeded() else { return }
            await hk.saveWater(ml: 240, date: now) // 240 mL ≈ 1 cup / 8 fl oz
        }
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
        }
    }
}
