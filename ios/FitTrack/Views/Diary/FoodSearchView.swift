import SwiftUI
import SwiftData
import Combine

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onAdd: (Food, Double) -> Void

    @State private var searchText = ""
    @State private var foods: [Food] = []
    @State private var favorites: [FoodFavorite] = []
    @State private var selectedFood: Food?
    @State private var servings: Double = 1.0

    // Online search state
    @State private var searchTab: SearchTab = .myFoods
    @State private var apiResults: [FoodAPIResult] = []
    @State private var selectedAPIResult: FoodAPIResult?
    @State private var apiServings: Double = 1.0
    @State private var isSearchingOnline = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var showingBarcodeScanner = false
    @State private var barcodeResult: FoodAPIResult?
    @State private var isLoadingBarcode = false

    enum SearchTab: String, CaseIterable {
        case myFoods = "My Foods"
        case favorites = "Favorites"
        case searchOnline = "Search Online"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented picker
                    Picker("Search Source", selection: $searchTab) {
                        ForEach(SearchTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if searchTab == .myFoods {
                        localFoodsList
                    } else if searchTab == .favorites {
                        favoritesList
                    } else {
                        onlineFoodsList
                    }
                }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBarcodeScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(Color.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                NavigationStack {
                    BarcodeScannerView { barcode in
                        showingBarcodeScanner = false
                        Task {
                            isLoadingBarcode = true
                            if let result = await FoodAPIService.shared.fetchByBarcode(ean: barcode) {
                                barcodeResult = result
                                selectedAPIResult = result
                                selectedFood = nil
                                apiServings = 1.0
                                searchTab = .searchOnline
                                apiResults = [result]
                            }
                            isLoadingBarcode = false
                        }
                    }
                    .navigationTitle("Scan Barcode")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingBarcodeScanner = false }
                                .foregroundStyle(Color.slateText)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: searchTab == .myFoods ? "Search foods" : "Search Open Food Facts")
            .onChange(of: searchText) { _, newValue in
                if searchTab == .searchOnline {
                    debounceOnlineSearch(query: newValue)
                }
            }
            .onChange(of: searchTab) { _, newTab in
                selectedFood = nil
                selectedAPIResult = nil
                if newTab == .searchOnline && !searchText.isEmpty {
                    debounceOnlineSearch(query: searchText)
                }
            }
            .onAppear {
                fetchAllFoods()
                fetchFavorites()
            }
        }
    }

    // MARK: - Local Foods List

    private var localFoodsList: some View {
        List {
            ForEach(filteredFoods, id: \.self) { food in
                foodRow(food)
                    .listRowBackground(Color.slateCard)
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Favorites List

    private var favoritesList: some View {
        List {
            if favorites.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "star.slash")
                            .font(.largeTitle)
                            .foregroundStyle(Color.slateText)
                        Text("No favorites yet")
                            .foregroundStyle(Color.slateText)
                        Text("Long-press a food to save it as a favorite")
                            .font(.caption)
                            .foregroundStyle(Color.slateText)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .listRowBackground(Color.slateBackground)
                .padding(.vertical, 40)
            } else {
                ForEach(favorites, id: \.self) { fav in
                    if let food = fav.food {
                        foodRow(food)
                            .listRowBackground(Color.slateCard)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(fav)
                                    try? modelContext.save()
                                    fetchFavorites()
                                } label: {
                                    Label("Unfavorite", systemImage: "star.slash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Online Foods List

    private var onlineFoodsList: some View {
        List {
            if isSearchingOnline {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.emerald)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                        .padding(.leading, 8)
                    Spacer()
                }
                .listRowBackground(Color.slateCard)
            } else if apiResults.isEmpty && !searchText.isEmpty {
                HStack {
                    Spacer()
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                    Spacer()
                }
                .listRowBackground(Color.slateCard)
            }

            ForEach(apiResults) { result in
                apiResultRow(result)
                    .listRowBackground(Color.slateCard)
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
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

    // MARK: - Food Row (Local)

    private func foodRow(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedFood === food {
                        selectedFood = nil
                    } else {
                        selectedFood = food
                        selectedAPIResult = nil
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
        .contextMenu {
            let isFav = isFavorite(food)
            Button {
                if isFav {
                    removeFavorite(food)
                } else {
                    addFavorite(food)
                }
            } label: {
                Label(isFav ? "Remove Favorite" : "Save as Favorite",
                      systemImage: isFav ? "star.slash" : "star.fill")
            }
        }
    }

    // MARK: - API Result Row

    private func apiResultRow(_ result: FoodAPIResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedAPIResult?.id == result.id {
                        selectedAPIResult = nil
                    } else {
                        selectedAPIResult = result
                        selectedFood = nil
                        apiServings = 1.0
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            if let brand = result.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(Color.slateText)
                                    .lineLimit(1)
                            }
                            Text("\(Int(result.calories)) kcal")
                                .font(.caption)
                                .foregroundStyle(Color.emerald)
                            Text("\(result.servingSize, specifier: "%.0f") \(result.servingUnit)")
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                        Text("via Open Food Facts")
                            .font(.caption2)
                            .foregroundStyle(Color.slateText.opacity(0.7))
                            .italic()
                    }
                    Spacer()
                    Image(systemName: selectedAPIResult?.id == result.id ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
            }

            if selectedAPIResult?.id == result.id {
                expandedAPIDetails(result)
            }
        }
    }

    // MARK: - Expanded Details (Local)

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

    // MARK: - Expanded Details (API)

    private func expandedAPIDetails(_ result: FoodAPIResult) -> some View {
        VStack(spacing: 12) {
            Divider()
                .overlay(Color.slateBorder)

            // Macros
            HStack(spacing: 16) {
                macroLabel("Protein", value: result.protein * apiServings, unit: "g", color: .blue)
                macroLabel("Carbs", value: result.carbs * apiServings, unit: "g", color: .orange)
                macroLabel("Fat", value: result.fat * apiServings, unit: "g", color: .pink)
            }

            // Servings
            HStack {
                Text("Servings")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    if apiServings > 0.5 {
                        apiServings -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.slateText)
                }

                Text("\(apiServings, specifier: "%.1f")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, alignment: .center)

                Button {
                    apiServings += 0.5
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
                Text("\(Int(result.calories * apiServings)) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            // Add button
            Button {
                addAPIResult(result)
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

    private func fetchFavorites() {
        let descriptor = FetchDescriptor<FoodFavorite>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        favorites = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func isFavorite(_ food: Food) -> Bool {
        favorites.contains { $0.food === food }
    }

    private func addFavorite(_ food: Food) {
        guard !isFavorite(food) else { return }
        let fav = FoodFavorite(food: food)
        modelContext.insert(fav)
        try? modelContext.save()
        fetchFavorites()
    }

    private func removeFavorite(_ food: Food) {
        if let fav = favorites.first(where: { $0.food === food }) {
            modelContext.delete(fav)
            try? modelContext.save()
            fetchFavorites()
        }
    }

    // MARK: - Online Search

    private func debounceOnlineSearch(query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            await performOnlineSearch(query: query)
        }
    }

    @MainActor
    private func performOnlineSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            apiResults = []
            return
        }
        isSearchingOnline = true
        apiResults = await FoodAPIService.shared.searchFoods(query: query)
        isSearchingOnline = false
    }

    // MARK: - Add API Result

    private func addAPIResult(_ result: FoodAPIResult) {
        // Save to local SwiftData so it's available offline
        let food = Food(
            name: result.name,
            servingSize: result.servingSize,
            servingUnit: result.servingUnit,
            calories: result.calories,
            protein: result.protein,
            carbs: result.carbs,
            fat: result.fat,
            fiber: result.fiber,
            brand: result.brand,
            isCustom: false
        )
        modelContext.insert(food)
        try? modelContext.save()

        onAdd(food, apiServings)
        dismiss()
    }
}
