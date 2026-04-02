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

    @State private var showingSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        unitSystemPicker
                        bodyStatsSection
                        goalSection
                        if previewTargets != nil {
                            resultsSection
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
            .onChange(of: weight) { recalculatePreview() }
            .onChange(of: height) { recalculatePreview() }
            .onChange(of: age) { recalculatePreview() }
            .onChange(of: gender) { recalculatePreview() }
            .onChange(of: activityLevel) { recalculatePreview() }
            .onChange(of: selectedGoal) { recalculatePreview() }
            .onChange(of: unitSystem) { recalculatePreview() }
            .overlay {
                if showingSaved {
                    savedToast
                }
            }
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
            saveProfile()
        } label: {
            Text("Save Profile")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.emerald)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.5)
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

    private func loadFromProfile(_ vm: MacrosViewModel) {
        let profile = vm.profile
        unitSystem = profile.unitSystem
        weight = String(format: "%.1f", profile.displayWeight)
        height = String(format: "%.1f", profile.displayHeight)
        age = "\(profile.age)"
        gender = profile.gender
        activityLevel = profile.activityLevel
        selectedGoal = profile.goal
        recalculatePreview()
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
