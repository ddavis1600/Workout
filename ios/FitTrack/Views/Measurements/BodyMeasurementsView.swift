import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                if measurements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ruler")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.slateText)
                        Text("No measurements yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Text("Tap + to record your body measurements.")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        if measurements.count >= 2 {
                            trendSection
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(measurements) { m in
                            measurementRow(m)
                                .listRowBackground(Color.slateBackground)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                modelContext.delete(measurements[i])
                            }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Measurements")
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMeasurementSheet()
            }
        }
    }

    // MARK: - Trend Chart

    private var trendSection: some View {
        let sorted = measurements.sorted { $0.date < $1.date }
        let waistData = sorted.compactMap { m -> (date: Date, value: Double)? in
            guard let v = m.waist else { return nil }
            return (m.date, v)
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Waist Trend")
                .font(.headline)
                .foregroundStyle(Color.ink)

            if waistData.count >= 2 {
                Chart {
                    ForEach(waistData, id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value("inches", point.value))
                            .foregroundStyle(Color.emerald)
                        PointMark(x: .value("Date", point.date), y: .value("inches", point.value))
                            .foregroundStyle(Color.emerald)
                            .symbolSize(30)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.slateBorder)
                        AxisValueLabel().foregroundStyle(Color.slateText)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.slateBorder)
                        AxisValueLabel().foregroundStyle(Color.slateText)
                    }
                }
                .frame(height: 180)
            } else {
                Text("Log waist measurements to see trends")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
    }

    // MARK: - Row

    private func measurementRow(_ m: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(m.date.formatted(as: "MMM d, yyyy"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)

            let items: [(String, Double?)] = [
                ("Chest", m.chest), ("Waist", m.waist), ("Hips", m.hips),
                ("Shoulders", m.shoulders), ("Neck", m.neck),
                ("L Bicep", m.bicepLeft), ("R Bicep", m.bicepRight),
                ("L Thigh", m.thighLeft), ("R Thigh", m.thighRight),
                ("Body Fat %", m.bodyFatPercent)
            ]

            let filled = items.compactMap { item -> (String, Double)? in
                guard let v = item.1 else { return nil }
                return (item.0, v)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(filled, id: \.0) { label, value in
                    VStack(spacing: 2) {
                        Text(label == "Body Fat %" ? "\(value, specifier: "%.1f")%" : "\(value, specifier: "%.1f")\"")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.emerald)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color.slateText)
                    }
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
    }
}

// MARK: - Add Measurement Sheet

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var chest = ""
    @State private var waist = ""
    @State private var hips = ""
    @State private var shoulders = ""
    @State private var neck = ""
    @State private var bicepLeft = ""
    @State private var bicepRight = ""
    @State private var thighLeft = ""
    @State private var thighRight = ""
    @State private var bodyFat = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(.emerald)
                            .foregroundStyle(Color.ink)
                            .padding(12)
                            .background(Color.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        measurementField("Chest (in)", text: $chest)
                        measurementField("Waist (in)", text: $waist)
                        measurementField("Hips (in)", text: $hips)
                        measurementField("Shoulders (in)", text: $shoulders)
                        measurementField("Neck (in)", text: $neck)
                        measurementField("Left Bicep (in)", text: $bicepLeft)
                        measurementField("Right Bicep (in)", text: $bicepRight)
                        measurementField("Left Thigh (in)", text: $thighLeft)
                        measurementField("Right Thigh (in)", text: $thighRight)
                        measurementField("Body Fat %", text: $bodyFat)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.emerald)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func measurementField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(Color.ink)
    }

    private func save() {
        let m = BodyMeasurement(date: date)
        m.chest = Double(chest)
        m.waist = Double(waist)
        m.hips = Double(hips)
        m.shoulders = Double(shoulders)
        m.neck = Double(neck)
        m.bicepLeft = Double(bicepLeft)
        m.bicepRight = Double(bicepRight)
        m.thighLeft = Double(thighLeft)
        m.thighRight = Double(thighRight)
        let bodyFatValue = Double(bodyFat)
        m.bodyFatPercent = bodyFatValue
        modelContext.insert(m)
        try? modelContext.save()

        // F9 — write body-fat to Apple Health if the user provided one.
        // requestAuthorizationIfNeeded is the V2-bundle gate: if the
        // user has already granted access for the bodyFat write set,
        // it's a no-op; otherwise this is the one-shot prompt.
        if let percent = bodyFatValue, percent > 0 {
            let captureDate = date
            Task {
                let hk = HealthKitManager.shared
                guard hk.isAvailable, await hk.requestAuthorizationIfNeeded() else { return }
                await hk.saveBodyFatPercentage(percent, date: captureDate)
            }
        }

        dismiss()
    }
}
