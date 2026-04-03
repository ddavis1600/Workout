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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        modePicker
                        if manualMode {
                            manualEntrySection
                        } else {
                            unitSystemPicker
                            bodyStatsSection
                            goalSection
                            calculateButton
                            if hasCalculated, previewTargets != nil {
                                resultsSection
                            }
                        }
                        saveButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Macros")
            .onAppear {
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
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)

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
                .foregroundStyle(.white)
        }
    }

    // MARK: - Unit System

    private var unitSystemPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unit System")
                .font(.headline)
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.blue.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // TDEE
            VStack(spacing: 4) {
                Text("Your TDEE")
                    .font(.subheadline)
                    .foregroundStyle(Color.slateText)
                Text("\(Int(previewTDEE))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.emerald)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(manualMode ? !isManualValid : (!isFormValid || !hasCalculated))
        .opacity((manualMode ? isManualValid : (isFormValid && hasCalculated)) ? 1.0 : 0.5)
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        VStack {
            Spacer()
            Text("Profile saved!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
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

        try? modelContext.save()
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
