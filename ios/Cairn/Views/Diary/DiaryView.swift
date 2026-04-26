import SwiftUI
import SwiftData
import PhotosUI

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    // Favorites live-update as the user toggles star in the search view
    // (swipe-to-unfavorite or long-press in FoodSearchView).
    @Query(sort: \FoodFavorite.createdAt, order: .reverse) private var favorites: [FoodFavorite]
    @State private var viewModel: DiaryViewModel?
    @State private var favoriteToAdd: FoodFavorite? = nil

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
    @State private var showMacros = false
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
                if !favorites.isEmpty {
                    favoritesStrip
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                mealSections
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Labeled pill instead of a bare icon (r2 feedback item 3)
                    // — users were missing it when it was just chart.pie.fill.
                    Button {
                        showMacros = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.pie.fill")
                                .font(.caption.weight(.semibold))
                            Text("Macros")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.emerald)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.emerald.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.emerald.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
            }
            .sheet(isPresented: $showMacros) {
                MacrosView()
            }
            // Favorite-chip → quick-add sheet. Lets the user pick meal +
            // servings without going through the full food-search flow.
            .sheet(item: $favoriteToAdd) { fav in
                if let food = fav.food {
                    FavoriteQuickAddSheet(food: food) { mealType, servings in
                        viewModel?.addEntry(food: food, mealType: mealType, servings: servings)
                    }
                }
            }
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
        // Tapping anywhere on the summary card jumps to the full MacrosView
        // so the affordance to "see / edit all my targets" is one tap away
        // (item 3 from beta feedback).
        NavigationLink {
            MacrosView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily Targets")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.slateText)
                }
                .padding(.bottom, 2)

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

                Text("Tap to view full macros →")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.emerald)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Favorites Strip

    /// Horizontal scrollable row of favorite foods, surfaced on the Diary
    /// page itself so users don't have to open food search → favorites tab
    /// to reuse their common foods. Tap a chip to open a small picker
    /// (meal + servings) and add to today's diary in two taps.
    ///
    /// Favorites are still managed via FoodSearchView (long-press a food
    /// in search to favorite it, swipe to unfavorite). That UI continues
    /// to be the source of truth — this strip is a shortcut, not a
    /// replacement.
    private var favoritesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("Favorites")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.slateText)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favorites, id: \.self) { fav in
                        if let food = fav.food {
                            favoriteChip(food: food, favorite: fav)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func favoriteChip(food: Food, favorite: FoodFavorite) -> some View {
        Button {
            favoriteToAdd = favorite
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("\(Int(food.calories.rounded())) kcal")
                    .font(.caption2)
                    .foregroundStyle(Color.slateText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 110, alignment: .leading)
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(favorite)
                modelContext.saveOrLog("DiaryView.removeFavorite")
            } label: {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
        }
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

// MARK: - Favorite Quick-Add Sheet

/// Small presentation-detent sheet for adding a favorited food to the
/// diary in one pass: pick a meal, adjust servings, tap Add. Picks the
/// time-of-day appropriate meal by default.
private struct FavoriteQuickAddSheet: View {
    let food: Food
    let onAdd: (_ mealType: String, _ servings: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mealType: String = defaultMealForNow()
    @State private var servings: Double = 1.0

    private static let mealOptions: [(id: String, label: String, icon: String)] = [
        ("breakfast", "Breakfast", "sunrise.fill"),
        ("lunch",     "Lunch",     "sun.max.fill"),
        ("dinner",    "Dinner",    "moon.stars.fill"),
        ("snack",     "Snack",     "leaf.fill"),
    ]

    /// Default meal slot based on current hour — most users add their
    /// current meal, so skip a tap when we can infer it.
    private static func defaultMealForNow() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<11:  return "breakfast"
        case 11..<15: return "lunch"
        case 15..<18: return "snack"
        default:      return "dinner"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    // Food summary header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        if let brand = food.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                        HStack(spacing: 12) {
                            macroTag("\(Int((food.calories * servings).rounded())) kcal", .emerald)
                            macroTag("P \(Int((food.protein * servings).rounded()))g", .blue)
                            macroTag("C \(Int((food.carbs * servings).rounded()))g", .orange)
                            macroTag("F \(Int((food.fat * servings).rounded()))g", .pink)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Meal picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Meal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.slateText)
                            .textCase(.uppercase)
                        HStack(spacing: 6) {
                            ForEach(Self.mealOptions, id: \.id) { opt in
                                Button { mealType = opt.id } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: opt.icon)
                                            .font(.subheadline)
                                        Text(opt.label)
                                            .font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(mealType == opt.id ? Color.emerald.opacity(0.2) : Color.slateCard)
                                    .foregroundStyle(mealType == opt.id ? Color.emerald : Color.slateText)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(mealType == opt.id ? Color.emerald : Color.slateBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Servings stepper
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Servings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.slateText)
                            .textCase(.uppercase)
                        HStack {
                            Button { servings = max(0.25, servings - 0.25) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.emerald)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text(String(format: servings.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", servings))
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Button { servings += 0.25 } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.emerald)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.slateCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(mealType, servings)
                        dismiss()
                    }
                    .foregroundStyle(Color.emerald)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func macroTag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
