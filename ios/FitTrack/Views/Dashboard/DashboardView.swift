import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            List {
                    welcomeHeader
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)

                    if let vm = viewModel {
                        if vm.profile == nil || vm.profile?.calorieTarget == 0 {
                            setupMacrosCard
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                        } else {
                            macroSummarySection(vm: vm)
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                        }

                        WeeklySummaryView()
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)

                        recentWorkoutsSection(vm: vm)
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Dashboard")
            .task {
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                } else {
                    viewModel?.refresh()
                }
            }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
        }
    }

    // MARK: - Setup Card

    private var setupMacrosCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.emerald)
            Text("Set up your macros")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Configure your body stats and goals to track your daily nutrition.")
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.emerald.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Macro Summary

    private func macroSummarySection(vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Nutrition")
                .font(.headline)
                .foregroundStyle(.white)

            let profile = vm.profile!
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MacroRing(label: "Calories", current: vm.todayCalories, target: profile.calorieTarget, color: .emerald)
                MacroRing(label: "Protein", current: vm.todayProtein, target: profile.proteinTarget, color: .blue)
                MacroRing(label: "Carbs", current: vm.todayCarbs, target: profile.carbTarget, color: .orange)
                MacroRing(label: "Fat", current: vm.todayFat, target: profile.fatTarget, color: .pink)
            }
            .padding()
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.slateBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Recent Workouts

    private func recentWorkoutsSection(vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundStyle(.white)

            if vm.recentWorkouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell")
                            .font(.title)
                            .foregroundStyle(Color.slateText)
                        Text("No workouts yet")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(vm.recentWorkouts, id: \.self) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        RecentWorkoutsCard(workout: workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
