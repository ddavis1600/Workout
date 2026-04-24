import SwiftUI
import SwiftData

struct MacrosView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MacrosViewModel?

    // Form state
    @State private var unitSystem = "imperial"
    @State private var weight = ""
    @State private var height = ""
    @State private var age = ""
    @State private var gender = "male"
    @State private var activityLevel = "moderate"
    @State private var selectedGoal = "maintain"

    // Preview calculation
    @State private var previewTargets: MacroTargets?
    @State private var previewTDEE: Double = 0
    @State private var hasCalculated = false

    // Manual entry mode
    @State private var manualMode = false
    @State private var manualCalories = ""
    @State private var manualProtein = ""
    @State private var manualCarbs = ""
    @State private var manualFat = ""

    @State private var showingSaved = false
    @State private var savedSummary: (calories: Int, protein: Int, carbs: Int, fat: Int)?

    @State private var proteinPct: Double = 0.30
    @State private var carbsPct: Double = 0.40
    @State private var fatPct: Double = 0.30

    var body: some View {
        NavigationStack {
            List {
                modePicker
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)

                if manualMode {
                    manualEntrySection
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                } else {
                    unitSystemPicker
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                    bodyStatsSection
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                    goalSection
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                    calculateButton
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                    if hasCalculated, previewTargets != nil {
                        resultsSection
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                        sliderSection
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    }
                }

                saveButton
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)

                savedTargetsCard
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Macros")
            .task {
                if viewModel == nil {
                    let vm = MacrosViewModel(modelContext: modelContext)
                    viewModel = vm
                    loadFromProfile(vm)
                }
            }
            .overlay {
                if showingSaved {
                    savedToast
                }
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entry Mode")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Picker("Mode", selection: $manualMode) {
                Text("Calculate").tag(false)
                Text("Manual Entry").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Manual Entry

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set Your Macros")
                .font(.headline)
                .foregroundStyle(Color.ink)

            VStack(spacing: 14) {
                macroField(label: "Daily Calories (kcal)", text: $manualCalories)
                macroField(label: "Protein (g)", text: $manualProtein)
                macroField(label: "Carbs (g)", text: $manualCarbs)
                macroField(label: "Fat (g)", text: $manualFat)
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )

            if let cal = Double(manualCalories), cal > 0 {
                MacroTargetsView(
                    calories: cal,
                    protein: Double(manualProtein) ?? 0,
                    carbs: Double(manualCarbs) ?? 0,
                    fat: Double(manualFat) ?? 0
                )
            }
        }
    }

    private func macroField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.slateBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: - Unit System

    private var unitSystemPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unit System")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Picker("Unit System", selection: $unitSystem) {
                Text("Imperial").tag("imperial")
                Text("Metric").tag("metric")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Body Stats

    private var bodyStatsSection: some View {
        BodyStatsForm(
            weight: $weight,
            height: $height,
            age: $age,
            gender: $gender,
            activityLevel: $activityLevel,
            unitSystem: unitSystem
        )
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    // MARK: - Goal

    private var goalSection: some View {
        GoalSelectorView(selectedGoal: $selectedGoal)
    }

    // MARK: - Calculate Button

    private var calculateButton: some View {
        Button {
            recalculatePreview()
            withAnimation {
                hasCalculated = true
            }
        } label: {
            Label("Calculate Macros", systemImage: "function")
                .font(.headline)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.emerald : Color.emerald.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: { hasCalculated = false }) {
                Label("Edit Profile", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // TDEE
            VStack(spacing: 4) {
                Text("Your TDEE")
                    .font(.subheadline)
                    .foregroundStyle(Color.slateText)
                Text("\(Int(previewTDEE))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("calories / day")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )

            if let targets = previewTargets {
                // Adjusted calories for goal
                VStack(spacing: 4) {
                    Text("Adjusted for \(selectedGoal.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                    Text("\(Int(targets.calories))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.emerald)
                    Text("calories / day")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )

                MacroTargetsView(
                    calories: targets.calories,
                    protein: targets.protein,
                    carbs: targets.carbs,
                    fat: targets.fat
                )
            }
        }
    }

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjust Macro Split")
                .font(.headline)
                .foregroundStyle(Color.ink)

            if let targets = previewTargets {
                let cal = targets.calories

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Protein")
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text("\(Int(cal * proteinPct / 4))g (\(Int(proteinPct * 100))%)")
                            .foregroundStyle(Color.emerald)
                    }
                    Slider(value: proteinBinding, in: 0.05...0.60, step: 0.01)
                        .tint(Color.emerald)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Carbs")
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text("\(Int(cal * carbsPct / 4))g (\(Int(carbsPct * 100))%)")
                            .foregroundStyle(.orange)
                    }
                    Slider(value: carbsBinding, in: 0.05...0.70, step: 0.01)
                        .tint(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Fat")
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text("\(Int(cal * fatPct / 9))g (\(Int(fatPct * 100))%)")
                            .foregroundStyle(.pink)
                    }
                    Slider(value: fatBinding, in: 0.05...0.60, step: 0.01)
                        .tint(.pink)
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

    private var proteinBinding: Binding<Double> {
        Binding(
            get: { proteinPct },
            set: { newVal in
                proteinPct = newVal
                let remaining = max(0, 1.0 - newVal)
                let total = carbsPct + fatPct
                if total > 0 {
                    carbsPct = remaining * (carbsPct / total)
                    fatPct   = remaining * (fatPct / total)
                } else {
                    carbsPct = remaining / 2
                    fatPct   = remaining / 2
                }
            }
        )
    }

    private var carbsBinding: Binding<Double> {
        Binding(
            get: { carbsPct },
            set: { newVal in
                carbsPct = newVal
                let remaining = max(0, 1.0 - newVal)
                let total = proteinPct + fatPct
                if total > 0 {
                    proteinPct = remaining * (proteinPct / total)
                    fatPct     = remaining * (fatPct / total)
                } else {
                    proteinPct = remaining / 2
                    fatPct     = remaining / 2
                }
            }
        )
    }

    private var fatBinding: Binding<Double> {
        Binding(
            get: { fatPct },
            set: { newVal in
                fatPct = newVal
                let remaining = max(0, 1.0 - newVal)
                let total = proteinPct + carbsPct
                if total > 0 {
                    proteinPct = remaining * (proteinPct / total)
                    carbsPct   = remaining * (carbsPct / total)
                } else {
                    proteinPct = remaining / 2
                    carbsPct   = remaining / 2
                }
            }
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            if manualMode {
                saveManualProfile()
            } else {
                saveProfile()
            }
        } label: {
            Text("Save Profile")
                .font(.headline)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.emerald)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(manualMode ? !isManualValid : (!isFormValid || !hasCalculated))
        .opacity((manualMode ? isManualValid : (isFormValid && hasCalculated)) ? 1.0 : 0.5)
    }

    // MARK: - Saved Targets Card

    @ViewBuilder
    private var savedTargetsCard: some View {
        if let s = savedSummary {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.emerald)
                    Text("Saved Targets")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                }

                HStack(spacing: 0) {
                    savedMacroPill(label: "Carbs", value: s.carbs, unit: "g", color: .orange)
                    savedMacroPill(label: "Fat", value: s.fat, unit: "g", color: .pink)
                    savedMacroPill(label: "Protein", value: s.protein, unit: "g", color: Color.emerald)
                }

                Text("\(s.calories) kcal / day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.emerald)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.emerald.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func savedMacroPill(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(unit)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.slateText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        VStack {
            Spacer()
            Text("Profile saved!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.emerald)
                .clipShape(Capsule())
                .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        guard let w = Double(weight), w > 0,
              let h = Double(height), h > 0,
              let a = Int(age), a > 0 else {
            return false
        }
        return true
    }

    private var isManualValid: Bool {
        guard let c = Double(manualCalories), c > 0 else { return false }
        return true
    }

    private func loadFromProfile(_ vm: MacrosViewModel) {
        let profile = vm.profile
        unitSystem = profile.unitSystem
        weight = profile.displayWeight > 0 ? String(format: "%.0f", profile.displayWeight) : ""
        height = profile.displayHeight > 0 ? String(format: "%.0f", profile.displayHeight) : ""
        age = profile.age > 0 ? "\(profile.age)" : ""
        gender = profile.gender
        activityLevel = profile.activityLevel
        selectedGoal = profile.goal

        // Load manual values from existing targets
        if profile.calorieTarget > 0 {
            manualCalories = String(format: "%.0f", profile.calorieTarget)
            manualProtein = String(format: "%.0f", profile.proteinTarget)
            manualCarbs = String(format: "%.0f", profile.carbTarget)
            manualFat = String(format: "%.0f", profile.fatTarget)
            savedSummary = (
                calories: Int(profile.calorieTarget),
                protein: Int(profile.proteinTarget),
                carbs: Int(profile.carbTarget),
                fat: Int(profile.fatTarget)
            )
        }
    }

    private func recalculatePreview() {
        guard let vm = viewModel,
              let w = Double(weight), w > 0,
              let h = Double(height), h > 0,
              let a = Int(age), a > 0 else {
            previewTargets = nil
            return
        }

        let weightKg = unitSystem == "imperial" ? MacroCalculator.lbsToKg(w) : w
        let heightCm = unitSystem == "imperial" ? MacroCalculator.inchesToCm(h) : h

        let bmr = MacroCalculator.calculateBMR(weightKg: weightKg, heightCm: heightCm, age: a, gender: gender)
        previewTDEE = MacroCalculator.calculateTDEE(bmr: bmr, activityLevel: activityLevel)

        previewTargets = vm.previewCalculation(
            weight: w,
            height: h,
            age: a,
            gender: gender,
            activityLevel: activityLevel,
            goal: selectedGoal,
            unitSystem: unitSystem
        )

        if let t = previewTargets, t.calories > 0 {
            let cal = t.calories
            proteinPct = (t.protein * 4) / cal
            carbsPct   = (t.carbs * 4) / cal
            fatPct     = (t.fat * 9) / cal
        }
    }

    private func saveProfile() {
        guard let vm = viewModel,
              let w = Double(weight),
              let h = Double(height),
              let a = Int(age) else { return }

        vm.updateProfile(
            weight: w,
            height: h,
            age: a,
            gender: gender,
            activityLevel: activityLevel,
            goal: selectedGoal,
            unitSystem: unitSystem
        )

        if let targets = previewTargets {
            let cal = targets.calories
            let adjProtein = Int(cal * proteinPct / 4)
            let adjCarbs   = Int(cal * carbsPct / 4)
            let adjFat     = Int(cal * fatPct / 9)
            vm.profile.calorieTarget = cal
            vm.profile.proteinTarget = Double(adjProtein)
            vm.profile.carbTarget    = Double(adjCarbs)
            vm.profile.fatTarget     = Double(adjFat)
            modelContext.saveOrLog("MacrosView.savePreviewProfile")
            savedSummary = (calories: Int(cal), protein: adjProtein, carbs: adjCarbs, fat: adjFat)
        }
        showSavedToast()
    }

    private func saveManualProfile() {
        guard let vm = viewModel else { return }

        let cal = Double(manualCalories) ?? 0
        let pro = Double(manualProtein) ?? 0
        let carb = Double(manualCarbs) ?? 0
        let fat = Double(manualFat) ?? 0

        vm.profile.calorieTarget = cal
        vm.profile.proteinTarget = pro
        vm.profile.carbTarget = carb
        vm.profile.fatTarget = fat
        vm.profile.updatedAt = .now

        modelContext.saveOrLog("MacrosView.saveManualProfile")
        savedSummary = (
            calories: Int(cal),
            protein: Int(pro),
            carbs: Int(carb),
            fat: Int(fat)
        )
        showSavedToast()
    }

    private func showSavedToast() {
        withAnimation {
            showingSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaved = false
            }
        }
    }
}
