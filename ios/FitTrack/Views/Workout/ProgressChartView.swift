import SwiftUI
import SwiftData
import Charts

struct ProgressChartView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkoutViewModel?
    @State private var selectedExercise: Exercise?
    @State private var exercises: [Exercise] = []
    @State private var chartData: [(date: Date, maxWeight: Double)] = []

    var body: some View {
        NavigationStack {
            List {
                    exercisePicker
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                    chartSection
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Progress")
            .task {
                if viewModel == nil {
                    let vm = WorkoutViewModel(modelContext: modelContext)
                    viewModel = vm
                    vm.fetchExercises()
                    exercises = vm.exercises
                }
            }
        }
    }

    // MARK: - Exercise Picker

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.slateText)

            Menu {
                ForEach(exercises, id: \.self) { exercise in
                    Button(exercise.name) {
                        selectedExercise = exercise
                        loadChartData(for: exercise)
                    }
                }
            } label: {
                HStack {
                    Text(selectedExercise?.name ?? "Select an exercise")
                        .foregroundStyle(selectedExercise != nil ? .white : Color.slateText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(Color.slateText)
                }
                .padding(12)
                .background(Color.slateCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.slateBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        Group {
            if selectedExercise == nil {
                placeholderView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track your progress",
                    subtitle: "Select an exercise above to see your weight progression over time."
                )
            } else if chartData.isEmpty {
                placeholderView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No data yet",
                    subtitle: "Log some workouts with this exercise to see your progress."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max Weight Over Time")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Chart {
                        ForEach(chartData, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.maxWeight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.emerald)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.maxWeight)
                            )
                            .foregroundStyle(Color.emerald)
                            .symbolSize(40)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(Color.slateBorder)
                            AxisValueLabel()
                                .foregroundStyle(Color.slateText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(Color.slateBorder)
                            AxisValueLabel()
                                .foregroundStyle(Color.slateText)
                        }
                    }
                    .chartPlotStyle { area in
                        area.background(Color.slateCard.opacity(0.3))
                    }
                    .frame(height: 250)
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
    }

    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.slateText)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
    }

    private func loadChartData(for exercise: Exercise) {
        guard let vm = viewModel else { return }
        chartData = vm.progressData(for: exercise)
    }
}
