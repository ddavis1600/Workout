import SwiftUI
import SwiftData
import Charts
import HealthKit

struct WeightTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @State private var showingLogSheet = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled = false
    @State private var timeRange: TimeRange = .thirtyDays
    @State private var pendingDelete: WeightEntry?

    enum TimeRange: String, CaseIterable {
        case thirtyDays = "30 Days"
        case ninetyDays = "90 Days"
        case allTime = "All Time"
    }

    private var unitSystem: String {
        profiles.first?.unitSystem ?? "metric"
    }

    private var unitLabel: String {
        unitSystem == "imperial" ? "lbs" : "kg"
    }

    private var filteredEntries: [WeightEntry] {
        let sorted = entries.sorted { $0.date < $1.date }
        switch timeRange {
        case .thirtyDays:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
            return sorted.filter { $0.date >= cutoff }
        case .ninetyDays:
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
            return sorted.filter { $0.date >= cutoff }
        case .allTime:
            return sorted
        }
    }

    private var recentEntries: [WeightEntry] {
        Array(entries.prefix(10))
    }

    private var weightTrend: Double? {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let recentWeights = entries.filter { $0.date >= sevenDaysAgo }.sorted { $0.date < $1.date }
        guard let first = recentWeights.first, let last = recentWeights.last, first.date != last.date else {
            return nil
        }
        let diff = last.displayWeight(unitSystem: unitSystem) - first.displayWeight(unitSystem: unitSystem)
        return diff
    }

    private var twelveMonthEntries: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        return entries.filter { $0.date >= cutoff }
    }

    private var twelveMonthHigh: Double? {
        twelveMonthEntries.map { $0.displayWeight(unitSystem: unitSystem) }.max()
    }

    private var twelveMonthLow: Double? {
        twelveMonthEntries.map { $0.displayWeight(unitSystem: unitSystem) }.min()
    }

    var body: some View {
        NavigationStack {
            List {
                    // Current weight card
                    currentWeightCard
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)

                    // Chart
                    if !filteredEntries.isEmpty {
                        chartSection
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    }

                    // Health sync toggle
                    healthSyncCard
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)

                    // Recent entries
                    if !recentEntries.isEmpty {
                        recentEntriesSection
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    } else {
                        emptyState
                            .listRowBackground(Color.slateBackground)
                            .listRowSeparator(.hidden)
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.emerald)
                    }
                    .accessibilityLabel("Log weight")
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogWeightSheet(unitSystem: unitSystem)
            }
            .confirmDestructive(
                item: $pendingDelete,
                title: "Delete weight entry?",
                message: { entry in
                    let formatted = entry.date.formatted(as: "MMM d, yyyy")
                    return "Removes the entry logged on \(formatted). This can't be undone."
                }
            ) { entry in
                modelContext.delete(entry)
                try? modelContext.save()
            }
        }
    }

    private func weightDiffPill(label: String, diff: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.slateText)
            Text("\(diff >= 0 ? "+" : "")\(diff, specifier: "%.1f") \(unit)")
                .font(.caption.bold())
                .foregroundColor(diff <= 0 ? .emerald : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.slateBackground)
        .cornerRadius(8)
    }

    private var currentWeightCard: some View {
        VStack(spacing: 8) {
            Text("Current Weight")
                .font(.subheadline)
                .foregroundColor(.slateText)

            if let latest = entries.first {
                Text("\(latest.displayWeight(unitSystem: unitSystem), specifier: "%.1f") \(unitLabel)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(Color.ink)

                if let trend = weightTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.bold())
                        Text("\(abs(trend), specifier: "%.1f") \(unitLabel) this week")
                            .font(.caption)
                    }
                    .foregroundColor(trend >= 0 ? .orange : .emerald)
                }

                let currentDisplay = latest.displayWeight(unitSystem: unitSystem)
                if let high = twelveMonthHigh, let low = twelveMonthLow,
                   twelveMonthEntries.count > 1 {
                    HStack(spacing: 12) {
                        weightDiffPill(label: "From High", diff: currentDisplay - high, unit: unitLabel)
                        weightDiffPill(label: "From Low", diff: currentDisplay - low, unit: unitLabel)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("-- \(unitLabel)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.slateText)
                Text("Log your first weight entry")
                    .font(.caption)
                    .foregroundColor(.slateText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private var chartSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundColor(Color.ink)

                Spacer()

                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Chart(filteredEntries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.displayWeight(unitSystem: unitSystem))
                )
                .foregroundStyle(Color.emerald)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.displayWeight(unitSystem: unitSystem))
                )
                .foregroundStyle(Color.emerald)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(v, specifier: "%.0f")")
                                .foregroundColor(.slateText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.slateBorder)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(as: "MMM d"))
                                .foregroundColor(.slateText)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    private var healthSyncCard: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health Sync")
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.ink)
                Text(healthSyncEnabled ? "Syncing with Health" : "Tap to enable")
                    .font(.caption)
                    .foregroundColor(.slateText)
            }

            Spacer()

            Toggle("", isOn: $healthSyncEnabled)
                .tint(.emerald)
                .onChange(of: healthSyncEnabled) { _, newValue in
                    if newValue && HealthKitManager.shared.isAvailable {
                        Task {
                            let _ = await HealthKitManager.shared.requestAuthorization()
                            await importFromHealthKit()
                        }
                    }
                }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
        .task {
            if healthSyncEnabled && HealthKitManager.shared.isAvailable {
                await importFromHealthKit()
            }
        }
    }

    private func importFromHealthKit() async {
        let startDate = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let hkWeights = await HealthKitManager.shared.fetchWeights(from: startDate, to: .now)

        guard !hkWeights.isEmpty else { return }

        let existingDates = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })

        for hkEntry in hkWeights {
            let entryDay = Calendar.current.startOfDay(for: hkEntry.date)
            if !existingDates.contains(entryDay) {
                let entry = WeightEntry(date: hkEntry.date, weight: hkEntry.weight, note: "From Health")
                modelContext.insert(entry)
            }
        }

        try? modelContext.save()
    }

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .foregroundColor(Color.ink)

            ForEach(recentEntries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.date.formatted(as: "MMM d, yyyy"))
                            .font(.body.weight(.medium))
                            .foregroundColor(Color.ink)

                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.caption)
                                .foregroundColor(.slateText)
                        }
                    }

                    Spacer()

                    Text("\(entry.displayWeight(unitSystem: unitSystem), specifier: "%.1f") \(unitLabel)")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.emerald)
                }
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDelete = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scalemass")
                .font(.system(size: 48))
                .foregroundColor(.slateText)
            Text("No weight entries yet")
                .font(.title3)
                .foregroundColor(Color.ink)
            Text("Tap + to log your weight")
                .font(.subheadline)
                .foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Log Weight Sheet

struct LogWeightSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let unitSystem: String
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled = false

    @State private var weightText = ""
    @State private var date = Date.now
    @State private var note = ""

    private var unitLabel: String {
        unitSystem == "imperial" ? "lbs" : "kg"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Weight input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight (\(unitLabel))")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            TextField("0.0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .padding()
                                .background(Color.slateCard)
                                .cornerRadius(12)
                                .foregroundColor(Color.ink)
                        }

                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.emerald)
                                .padding()
                                .background(Color.slateCard)
                                .cornerRadius(12)
                        }

                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note (optional)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            TextField("e.g. After morning workout", text: $note)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.slateCard)
                                .cornerRadius(12)
                                .foregroundColor(Color.ink)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWeight()
                    }
                    .disabled(Double(weightText) == nil)
                    .foregroundColor(.emerald)
                }
            }
            .keyboardDoneToolbar()
        }
        .presentationDetents([.medium])
    }

    private func saveWeight() {
        guard let displayValue = Double(weightText) else { return }
        let weightKg = WeightEntry.fromDisplay(displayValue, unitSystem: unitSystem)
        let entry = WeightEntry(date: date, weight: weightKg, note: note)
        modelContext.insert(entry)
        try? modelContext.save()

        if healthSyncEnabled {
            Task {
                await HealthKitManager.shared.saveWeight(weightKg, date: date)
            }
        }

        dismiss()
    }
}

#Preview {
    WeightTrackingView()
        .modelContainer(for: [WeightEntry.self, UserProfile.self], inMemory: true)
}
