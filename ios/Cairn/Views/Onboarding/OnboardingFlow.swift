import SwiftUI
import SwiftData
import HealthKit
import UserNotifications

/// Multi-step first-launch onboarding flow (audit ref F5).
///
/// Five screens, each a sub-view in this file:
///   1. **Welcome** — large logo + tagline + "Get Started" CTA.
///   2. **Goals** — pick 1–4 of: Build muscle / Lose weight /
///      Track nutrition / Daily habits.
///   3. **Permissions** — explains HK + Notifications BEFORE the
///      system prompts (M1 fix), then triggers them on tap.
///   4. **Profile** — name / age / weight / height. All optional,
///      "Set up later" skips without writing.
///   5. **Sample data** — toggle to seed 3 sample workouts +
///      1 week of habit completions so empty states aren't lonely.
///
/// On completion the view sets `@AppStorage("hasCompletedOnboarding")`
/// to true. `FitTrackApp` reads that to decide which root view to
/// show on launch.
///
/// Why a new file rather than expanding the existing
/// `OnboardingView.swift`: that one is a single-screen theme picker
/// with elaborate live-preview cards that's worth keeping as a
/// distinct affordance — it's now reused as a polish step *after*
/// the new flow finishes (see `ContentView` integration), so first-
/// time users still get to pick their palette.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum Step: Int, CaseIterable {
        case welcome, goals, permissions, profile, sampleData
    }

    @State private var step: Step = .welcome
    @State private var selectedGoals: Set<OnboardingGoal> = []

    // Profile fields — optional capture
    @State private var name: String = ""
    @State private var ageText: String = ""
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var unitSystem: String = "imperial"

    // Sample data toggle
    @State private var seedSampleData: Bool = false

    // Permission outcomes (UI-only — no fail state since user can
    // always grant later in Settings)
    @State private var healthGranted: Bool? = nil
    @State private var notifGranted: Bool? = nil

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                // Each step is its own sub-view; AnyView wrapping keeps
                // the transitions tidy without a 5-arm switch every
                // time we add chrome.
                Group {
                    switch step {
                    case .welcome:    welcomeStep
                    case .goals:      goalsStep
                    case .permissions: permissionsStep
                    case .profile:    profileStep
                    case .sampleData: sampleDataStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: step)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(s.rawValue <= step.rawValue ? Color.emerald : Color.slateBorder)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 92, weight: .semibold))
                .foregroundStyle(Color.emerald)
            VStack(spacing: 10) {
                Text("Welcome to FitTrack")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                Text("Your training, nutrition, and habits — all in one place.")
                    .font(.subheadline)
                    .foregroundStyle(Color.slateText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button {
                advance()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: Goals

    private var goalsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "What brings you here?",
                subtitle: "Pick one or more — we'll tailor the dashboard."
            )

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(OnboardingGoal.allCases) { goal in
                        GoalPickRow(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal),
                            toggle: {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            primaryAndSkipButtons(
                primary: "Continue",
                primaryEnabled: !selectedGoals.isEmpty,
                primaryAction: { advance() },
                skipAction: { advance() }
            )
        }
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Stay in sync",
                subtitle: "We'll only use what you let us — explained up front."
            )

            ScrollView {
                VStack(spacing: 14) {
                    PermissionExplainerCard(
                        icon: "heart.fill",
                        iconTint: .red,
                        title: "Apple Health",
                        bodyText: "Read steps, sleep, and resting heart rate so habit triggers and trends work. Write your weight, workouts, and nutrition so the Health app stays current.",
                        granted: healthGranted,
                        action: {
                            Task { healthGranted = await HealthKitManager.shared.requestAuthorization() }
                        },
                        actionLabel: healthGranted == nil ? "Allow Health Access" : "Granted"
                    )

                    PermissionExplainerCard(
                        icon: "bell.fill",
                        iconTint: .orange,
                        title: "Notifications",
                        bodyText: "Optional reminders for meals, workouts, and habit streaks. Each kind is individually toggleable in Settings — nothing fires until you opt in.",
                        granted: notifGranted,
                        action: {
                            Task { notifGranted = await requestNotificationAuth() }
                        },
                        actionLabel: notifGranted == nil ? "Enable Notifications" : "Granted"
                    )

                    Text("Camera and photo library prompt naturally when you use those features — we don't ask for them up front.")
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            primaryAndSkipButtons(
                primary: "Continue",
                primaryEnabled: true,
                primaryAction: { advance() },
                skipAction: { advance() },
                skipLabel: "Skip for now"
            )
        }
    }

    /// Wrap UNUserNotificationCenter's callback API in async/await so
    /// we can await the user's tap result inside the SwiftUI Task.
    private func requestNotificationAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
        }
    }

    // MARK: - Step 4: Profile

    private var profileStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "About you",
                subtitle: "All optional. Anything you skip you can fill in later."
            )

            ScrollView {
                VStack(spacing: 14) {
                    profileField(label: "Name", placeholder: "First name", text: $name)
                        .textInputAutocapitalization(.words)
                    profileField(label: "Age", placeholder: "25", text: $ageText)
                        .keyboardType(.numberPad)

                    Picker("Units", selection: $unitSystem) {
                        Text("Imperial (lb / in)").tag("imperial")
                        Text("Metric (kg / cm)").tag("metric")
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    profileField(
                        label: "Weight",
                        placeholder: unitSystem == "imperial" ? "150" : "68",
                        text: $weightText
                    )
                    .keyboardType(.decimalPad)
                    profileField(
                        label: "Height",
                        placeholder: unitSystem == "imperial" ? "68" : "173",
                        text: $heightText
                    )
                    .keyboardType(.decimalPad)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            primaryAndSkipButtons(
                primary: "Continue",
                primaryEnabled: true,
                primaryAction: { advance() },
                skipAction: { advance() },
                skipLabel: "Set up later"
            )
        }
    }

    private func profileField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
            TextField(placeholder, text: text)
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: - Step 5: Sample data

    private var sampleDataStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Try it with sample data?",
                subtitle: "We'll seed 3 example workouts + 7 days of habit check-ins so the app isn't empty on first open."
            )

            VStack(spacing: 18) {
                Toggle(isOn: $seedSampleData) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.emerald)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Seed sample data")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            Text("You can delete anything you don't want.")
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                    }
                }
                .tint(.emerald)
                .padding()
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
            }

            Button {
                finish()
            } label: {
                Text("Finish Setup")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Chrome helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    @ViewBuilder
    private func primaryAndSkipButtons(
        primary: String,
        primaryEnabled: Bool,
        primaryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void,
        skipLabel: String? = nil
    ) -> some View {
        VStack(spacing: 8) {
            Button(action: primaryAction) {
                Text(primary)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryEnabled ? Color.emerald : Color.emerald.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!primaryEnabled)

            if let skipLabel {
                Button(action: skipAction) {
                    Text(skipLabel)
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Flow control

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        step = next
    }

    private func finish() {
        // 1. Persist profile additions.
        let profile = profiles.first ?? {
            let p = UserProfile()
            modelContext.insert(p)
            return p
        }()
        if !name.isEmpty { profile.name = name }
        profile.unitSystem = unitSystem
        profile.goals = selectedGoals.map(\.rawValue).sorted()

        if let age = Int(ageText), age > 0 {
            profile.age = age
        }
        if let w = Double(weightText), w > 0 {
            profile.setWeight(fromDisplay: w)
        }
        if let h = Double(heightText), h > 0 {
            profile.setHeight(fromDisplay: h)
        }
        // Recompute targets if we have enough info — keeps the
        // dashboard's macro card from showing setup-required state
        // immediately after onboarding.
        if Int(ageText) != nil && Double(weightText) != nil && Double(heightText) != nil {
            profile.recalculateMacros()
        }
        profile.updatedAt = .now
        try? modelContext.save()

        // 2. Sample data — gated on the toggle.
        if seedSampleData {
            OnboardingSampleData.seed(context: modelContext)
        }

        // 3. Mark onboarding complete. ContentView observes this
        // AppStorage flag to swap from the flow to the main UI.
        withAnimation { hasCompletedOnboarding = true }
    }
}

// MARK: - Goal model

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case buildMuscle      = "build_muscle"
    case loseWeight       = "lose_weight"
    case trackNutrition   = "track_nutrition"
    case dailyHabits      = "daily_habits"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle:    return "Build muscle"
        case .loseWeight:     return "Lose weight"
        case .trackNutrition: return "Track nutrition"
        case .dailyHabits:    return "Daily habits"
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle:    return "Strength training, sets, and PRs."
        case .loseWeight:     return "Calorie targets and weight trends."
        case .trackNutrition: return "Macros, food diary, hydration."
        case .dailyHabits:    return "Streaks, reminders, and routines."
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle:    return "figure.strengthtraining.traditional"
        case .loseWeight:     return "scalemass.fill"
        case .trackNutrition: return "fork.knife"
        case .dailyHabits:    return "checkmark.circle.fill"
        }
    }
}

private struct GoalPickRow: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: goal.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Color.emerald)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(isSelected ? Color.emerald : Color.emerald.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(goal.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.slateText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.emerald : Color.slateBorder)
                    .font(.title3)
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.emerald : Color.slateBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions explainer card

private struct PermissionExplainerCard: View {
    let icon: String
    let iconTint: Color
    let title: String
    /// Stored as `bodyText` rather than `body` to avoid colliding with
    /// `View.body`'s required computed property.
    let bodyText: String
    let granted: Bool?
    let action: () -> Void
    let actionLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconTint)
                    .frame(width: 32, height: 32)
                    .background(iconTint.opacity(0.15), in: Circle())
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                if let granted, granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.emerald)
                }
            }
            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(actionLabel)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(granted == true ? Color.emerald.opacity(0.15) : Color.emerald)
                    .foregroundStyle(granted == true ? Color.emerald : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(granted == true)
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

#Preview {
    OnboardingFlow()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
