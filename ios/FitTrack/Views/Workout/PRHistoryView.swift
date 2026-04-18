import SwiftUI
import SwiftData

struct PRHistoryView: View {
    @Query private var allSets: [WorkoutSet]

    private var exerciseNames: [String] {
        let names = Set(allSets.compactMap { $0.exercise?.name })
        return names.sorted()
    }

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            if exerciseNames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.slateText)
                    Text("No personal records yet")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text("Log workouts to start tracking your PRs")
                        .font(.subheadline)
                        .foregroundStyle(Color.slateText)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                List {
                    ForEach(exerciseNames, id: \.self) { name in
                        let records = PRService.allPRs(for: name, allSets: allSets)
                        if !records.isEmpty {
                            exercisePRCard(name: name, records: records)
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.slateBackground, for: .navigationBar)
    }

    private func exercisePRCard(name: String, records: [PRRecord]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
            }

            ForEach(records, id: \.type.rawValue) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.type.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.emerald)
                        Text(record.date.formatted(as: "MMM d, yyyy"))
                            .font(.caption)
                            .foregroundStyle(Color.slateText)
                    }
                    Spacer()
                    Text(formattedValue(record))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.ink)
                }
                .padding(10)
                .background(Color.slateBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private func formattedValue(_ record: PRRecord) -> String {
        switch record.type {
        case .maxWeight:
            return String(format: "%.1f lbs", record.value)
        case .maxReps:
            return "\(Int(record.value)) reps"
        case .maxVolume:
            return String(format: "%.0f lbs", record.value)
        }
    }
}
