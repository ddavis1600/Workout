import SwiftUI
import SwiftData
import Charts
import HealthKit

// Phase B detail sheet. Replaces the Phase A placeholder.
//
// Layout (top → bottom):
//   1. Range picker — 1D / 7D / 30D / 90D / 1Y, persisted in
//      @AppStorage so the user's last selection sticks across
//      sheets and launches.
//   2. Full-height chart — same chart variant as the on-card
//      sparkline, but blown up with axes, a legend, and (in C13)
//      per-metric overlays (SpO2 95% band, HRV normal range,
//      goal lines, etc.).
//   3. Stats summary card — avg / min / max for the selected
//      window. Latest reading shown alongside.
//   4. "Open in Apple Health" button — `x-apple-health://` deep
//      link. Falls back to the app's Browse tab when the
//      catalog entry has no specific path.
//
// The sheet refetches samples whenever the range changes
// (via `service.fetchSeries(for:days:)`) so each window is
// pulled fresh rather than sliced from the dashboard's cached
// summary. That keeps a 1Y view from being capped at the
// catalog's 30-day window.
struct MetricDetailSheet: View {
    let summary: MetricSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Service handle — used to refetch over a custom day range
    /// when the user changes the picker.
    private let service = HealthDashboardService.shared

    /// Persists the selected range across sheet dismiss/restore
    /// AND across launches. Single key (not per-metric) — the
    /// user's preferred granularity tends to be consistent.
    @AppStorage("metric.detailRangeDays") private var rangeDays: Int = 30

    /// Samples fetched for the current `rangeDays`. Populated on
    /// appear and on range change.
    @State private var samples: [MetricSample] = []
    @State private var isLoading: Bool = false

    // Weight + body temp depend on UserProfile.unitSystem; we
    // duplicate the look-up here rather than passing it through.
    @Query private var profiles: [UserProfile]
    private var unitSystem: String {
        profiles.first?.unitSystem ?? "imperial"
    }

    private static let ranges: [(label: String, days: Int)] = [
        ("1D", 1), ("7D", 7), ("30D", 30), ("90D", 90), ("1Y", 365),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    rangePicker
                    chartCard
                    statsCard
                    openInHealthButton
                }
                .padding(16)
            }
            .background(Color.slateBackground)
            .navigationTitle(summary.metric.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: rangeDays) {
            await reload()
        }
    }

    // MARK: - Sub-sections

    private var rangePicker: some View {
        Picker("Range", selection: $rangeDays) {
            ForEach(Self.ranges, id: \.days) { range in
                Text(range.label).tag(range.days)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: summary.metric.icon)
                    .foregroundStyle(Color.emerald)
                Text(summary.metric.label)
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }

            if samples.isEmpty && !isLoading {
                noDataPlaceholder
            } else {
                MetricDetailChart(
                    metric: summary.metric,
                    samples: samples,
                    unitSystem: unitSystem
                )
                .frame(minHeight: 260)
            }

            // Per-metric "what's normal" caption — shown only for
            // metrics where context helps the user read the chart
            // (HRV, SpO2). Source: Apple Health guidance / common
            // adult medical references.
            if let caption = MetricSpec.normalCaption(for: summary.metric) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slateCard)
        .cornerRadius(12)
    }

    private var statsCard: some View {
        let stats = MetricStats(samples: samples, metric: summary.metric, unitSystem: unitSystem)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            // Two-column grid wraps cleanly on small phones; on
            // wider devices (iPad) the GridItem .flexible() lets
            // the rows breathe without forcing a third column.
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                StatTile(label: "Latest",  value: stats.latestText)
                StatTile(label: "Average", value: stats.averageText)
                StatTile(label: "Min",     value: stats.minText)
                StatTile(label: "Max",     value: stats.maxText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slateCard)
        .cornerRadius(12)
    }

    private var openInHealthButton: some View {
        Button {
            // Apple's `x-apple-health://` URL scheme: the path
            // segments after the scheme deep-link to the matching
            // Browse > Category > Metric page. When no specific
            // path is registered for this metric we fall back to
            // the app root, which lands on the Summary tab — still
            // useful for users who want to open Health.
            let path = summary.metric.healthAppPath ?? ""
            if let url = URL(string: "x-apple-health://\(path)") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                Text("Open in Apple Health")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.emerald)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var noDataPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No \(summary.metric.label.lowercased()) samples in this window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Refresh

    private func reload() async {
        isLoading = true
        let pulled = await service.fetchSeries(for: summary.metric, days: rangeDays)
        samples = pulled
        isLoading = false
    }
}

// MARK: - Stats helper

/// Pure-value formatter for the stats card. Splitting it out keeps
/// the sheet body readable, and makes the per-metric formatting
/// reusable from C13's specialised overlays.
private struct MetricStats {
    let samples: [MetricSample]
    let metric: HealthMetric
    let unitSystem: String

    private var values: [Double] { samples.map(\.value).filter { $0 > 0 } }

    var latestText: String { format(samples.last?.value) }
    var averageText: String {
        guard !values.isEmpty else { return "—" }
        return format(values.reduce(0, +) / Double(values.count))
    }
    var minText: String { format(values.min()) }
    var maxText: String { format(values.max()) }

    private func format(_ v: Double?) -> String {
        guard let v else { return "—" }
        switch metric.id {
        case "sleep":
            let h = Int(v); let m = Int((v - Double(h)) * 60)
            return "\(h)h \(m)m"
        case "weight":
            let display = unitSystem == "metric" ? v : v * 2.20462
            return String(format: "%.1f \(unitSystem == "metric" ? "kg" : "lb")", display)
        case "bodyTemperature":
            let display = unitSystem == "metric" ? v : v * 9/5 + 32
            return String(format: "%.1f\(unitSystem == "metric" ? "°C" : "°F")", display)
        case "spo2":             return String(format: "%.1f%%", v * 100)
        case "hrv":              return "\(Int(v.rounded())) ms"
        case "respiratoryRate":  return String(format: "%.1f br/min", v)
        case "vo2Max":           return String(format: "%.1f", v)
        case "activeEnergy":     return "\(Int(v.rounded())) kcal"
        case "exerciseMinutes":  return "\(Int(v.rounded())) min"
        case "standHours":       return "\(Int(v)) hr"
        case "steps":            return v.formatted(.number)
        case "restingHR":        return "\(Int(v.rounded())) BPM"
        default:                 return v.formatted(.number)
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Per-metric specs

/// Per-metric overlays + captions for the detail sheet. Centralised
/// so the chart variants stay generic; specifics (HRV's 20–80 ms
/// band, SpO2's 95% threshold, Exercise's 30-min goal, Stand's 12-
/// hour goal) live here as data, not view-tree branching.
enum MetricSpec {
    /// Filled band drawn behind the chart line — useful for "this
    /// is the normal range" framing on HRV/SpO2.
    static func normalBand(for metric: HealthMetric) -> ClosedRange<Double>? {
        switch metric.id {
        case "hrv":   return 20.0...80.0   // ms; broad adult range
        case "spo2":  return 95.0...100.0  // % displayed (post-conversion)
        default:      return nil
        }
    }

    /// Single horizontal goal line — exercise / stand rings.
    static func goalLine(for metric: HealthMetric) -> Double? {
        switch metric.id {
        case "exerciseMinutes": return 30
        case "standHours":      return 12
        default:                return nil
        }
    }

    /// One-liner shown below the chart for context-helpful metrics.
    static func normalCaption(for metric: HealthMetric) -> String? {
        switch metric.id {
        case "hrv":
            return "Normal adult HRV (SDNN) typically falls between 20–80 ms — higher tends to mean better recovery."
        case "spo2":
            return "Healthy resting blood oxygen is 95–100%. Sustained readings below 95% are worth checking with a clinician."
        case "exerciseMinutes":
            return "Apple's default Exercise ring goal is 30 minutes per day."
        case "standHours":
            return "Apple's default Stand ring goal is 12 hours per day."
        default:
            return nil
        }
    }
}

// MARK: - Detail chart

/// Full-height chart used inside the detail sheet. Dispatches off
/// `metric.chart` the same way the on-card sparkline does, but
/// renders axes, a legend, and per-metric overlays from MetricSpec
/// (threshold bands, goal lines).
struct MetricDetailChart: View {
    let metric: HealthMetric
    let samples: [MetricSample]
    let unitSystem: String

    var body: some View {
        switch metric.chart {
        case .line, .sparkline, .weightLine:
            LineDetailChart(
                samples: displaySamples,
                accent: Color.emerald,
                overlayBand: MetricSpec.normalBand(for: metric)
            )
        case .bar:
            BarDetailChart(
                samples: samples,
                accent: Color.emerald,
                goalLine: MetricSpec.goalLine(for: metric)
            )
        case .barWithGoal:
            BarDetailChart(
                samples: samples,
                accent: Color.emerald,
                goalLine: MetricSpec.goalLine(for: metric)
            )
        case .bloodPressureLines:
            BloodPressureDetailChart(samples: samples, accent: Color.emerald)
        case .sparseDot:
            DotDetailChart(
                samples: displaySamples,
                accent: Color.emerald,
                overlayBand: MetricSpec.normalBand(for: metric)
            )
        case .dotBand:
            DotDetailChart(
                samples: displaySamples,
                accent: Color.emerald,
                overlayBand: MetricSpec.normalBand(for: metric)
            )
        case .sleepStackedBar:
            SleepDetailChart(samples: samples)
        case .macroStackedBar:
            MacroBalanceDetailChart(samples: samples)
        case .energyDualLine:
            EnergyBalanceDetailChart(samples: samples)
        }
    }

    /// Apply unit conversion for metrics whose service-side value
    /// differs from the displayed unit (weight kg → lb, body temp
    /// °C → °F). For everything else, samples flow through
    /// unmodified.
    private var displaySamples: [MetricSample] {
        switch metric.id {
        case "weight" where unitSystem != "metric":
            return samples.map { MetricSample(date: $0.date, value: $0.value * 2.20462, secondary: $0.secondary, stages: $0.stages) }
        case "bodyTemperature" where unitSystem != "metric":
            return samples.map { MetricSample(date: $0.date, value: $0.value * 9/5 + 32, secondary: $0.secondary, stages: $0.stages) }
        case "spo2":
            // Display %, not fraction.
            return samples.map { MetricSample(date: $0.date, value: $0.value * 100, secondary: $0.secondary, stages: $0.stages) }
        default:
            return samples
        }
    }
}

private struct LineDetailChart: View {
    let samples: [MetricSample]
    let accent: Color
    /// Optional "normal range" band drawn behind the line (e.g. HRV
    /// 20–80 ms). When nil, no band renders.
    let overlayBand: ClosedRange<Double>?

    var body: some View {
        Chart {
            if let band = overlayBand {
                // RectangleMark anchored to a constant range pair —
                // SwiftUI Charts paints a horizontal stripe across
                // the full plot width.
                RectangleMark(
                    yStart: .value("Lower", band.lowerBound),
                    yEnd:   .value("Upper", band.upperBound)
                )
                .foregroundStyle(accent.opacity(0.12))
            }
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Value", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
    }
}

private struct BarDetailChart: View {
    let samples: [MetricSample]
    let accent: Color
    /// Horizontal goal line drawn over the bars (e.g. Exercise's
    /// 30-min default goal). When nil, no line renders.
    let goalLine: Double?

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                BarMark(
                    x: .value("Date", sample.date, unit: .day),
                    y: .value("Value", sample.value)
                )
                .foregroundStyle(accent)
                .cornerRadius(2)
            }
            if let goal = goalLine {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(accent.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal \(Int(goal))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
    }
}

private struct DotDetailChart: View {
    let samples: [MetricSample]
    let accent: Color
    /// Threshold band — SpO2's 95–100% healthy range, etc.
    let overlayBand: ClosedRange<Double>?

    var body: some View {
        Chart {
            if let band = overlayBand {
                RectangleMark(
                    yStart: .value("Lower", band.lowerBound),
                    yEnd:   .value("Upper", band.upperBound)
                )
                .foregroundStyle(accent.opacity(0.12))
            }
            ForEach(samples) { sample in
                PointMark(
                    x: .value("Date", sample.date),
                    y: .value("Value", sample.value)
                )
                .foregroundStyle(accent)
                .symbolSize(36)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
    }
}

private struct BloodPressureDetailChart: View {
    let samples: [MetricSample]
    let accent: Color
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Systolic", sample.value),
                    series: .value("Series", "Systolic")
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                if let dia = sample.secondary {
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Diastolic", dia),
                        series: .value("Series", "Diastolic")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(.visible)
    }
}

private struct MacroBalanceDetailChart: View {
    let samples: [MetricSample]
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                if let m = sample.macros, m.totalGrams > 0 {
                    BarMark(
                        x: .value("Day", sample.date, unit: .day),
                        y: .value("Protein", m.proteinGrams)
                    )
                    .foregroundStyle(by: .value("Macro", "Protein"))
                    BarMark(
                        x: .value("Day", sample.date, unit: .day),
                        y: .value("Carbs", m.carbsGrams)
                    )
                    .foregroundStyle(by: .value("Macro", "Carbs"))
                    BarMark(
                        x: .value("Day", sample.date, unit: .day),
                        y: .value("Fat", m.fatGrams)
                    )
                    .foregroundStyle(by: .value("Macro", "Fat"))
                }
            }
        }
        .chartForegroundStyleScale([
            "Protein": Color.emerald,
            "Carbs":   Color.emerald.opacity(0.65),
            "Fat":     Color.emerald.opacity(0.4),
        ])
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(.visible)
    }
}

private struct EnergyBalanceDetailChart: View {
    let samples: [MetricSample]
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Intake", sample.value),
                    series: .value("Series", "Intake")
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
                if let burned = sample.secondary {
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Burned", burned),
                        series: .value("Series", "Burned")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(.visible)
    }
}

private struct SleepDetailChart: View {
    let samples: [MetricSample]
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                if let stages = sample.stages, stages.totalSeconds > 0 {
                    BarMark(
                        x: .value("Night", sample.date, unit: .day),
                        y: .value("Hours", stages.core / 3600.0)
                    )
                    .foregroundStyle(by: .value("Stage", "Core"))
                    BarMark(
                        x: .value("Night", sample.date, unit: .day),
                        y: .value("Hours", stages.rem / 3600.0)
                    )
                    .foregroundStyle(by: .value("Stage", "REM"))
                    BarMark(
                        x: .value("Night", sample.date, unit: .day),
                        y: .value("Hours", stages.deep / 3600.0)
                    )
                    .foregroundStyle(by: .value("Stage", "Deep"))
                }
            }
        }
        .chartForegroundStyleScale([
            "Core": Color.emerald.opacity(0.55),
            "REM":  Color.emerald.opacity(0.85),
            "Deep": Color.emerald,
        ])
        .chartYAxis { AxisMarks(position: .leading) }
        .chartLegend(.visible)
    }
}
