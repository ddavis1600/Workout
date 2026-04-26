import SwiftUI
import SwiftData
import Charts

// One Tier 1 card — label, big value, unit. The sparkline area is a
// placeholder rectangle in this commit; the per-metric Charts variants
// land in the next commit and replace `sparklinePlaceholder` per
// `summary.metric.chart`. Tap → MetricDetailSheet.
struct MetricCard: View {
    let summary: MetricSummary
    @State private var showingDetail = false

    // Weight is the only Phase A metric that re-formats to user pref;
    // the others use static units. Reads UserProfile via SwiftData
    // since `unitSystem` lives on the @Model, not UserDefaults.
    @Query private var profiles: [UserProfile]

    var body: some View {
        Button { showingDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                header
                value
                sparkline
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.slateCard)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            MetricDetailSheet(summary: summary)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.metric.icon)
                .foregroundStyle(Color.emerald)
            Text(summary.metric.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(formattedValue)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(displayUnit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sparkline: some View {
        switch summary.metric.chart {
        case .sleepStackedBar:
            SleepStackedSparkline(samples: summary.series)
        case .line, .sparkline:
            LineSparkline(samples: summary.series, accent: Color.emerald)
        case .bar, .barWithGoal:
            // `barWithGoal` adds a goal-line overlay in the per-metric
            // detail sheet; the on-card sparkline reuses the plain bars
            // so the dashboard reads consistently across cards.
            BarSparkline(samples: summary.series, accent: Color.emerald)
        case .weightLine:
            // Weight uses raw kg values from the service; sparkline is
            // unitless (no axis labels), so the relative shape reads
            // identically regardless of user's unit pref.
            LineSparkline(samples: summary.series, accent: Color.emerald)
        case .bloodPressureLines:
            DualLineSparkline(samples: summary.series, accent: Color.emerald)
        case .sparseDot:
            DotSparkline(samples: summary.series, accent: Color.emerald)
        case .dotBand:
            // SpO2 — dots with a 95% threshold marker. Specialised
            // overlay (coloured threshold band) lives in the detail
            // sheet; the on-card sparkline stays minimal.
            DotSparkline(samples: summary.series, accent: Color.emerald)
        }
    }

    private var unitSystem: String {
        profiles.first?.unitSystem ?? "imperial"
    }

    private var displayUnit: String {
        if summary.metric.id == "weight" {
            return unitSystem == "metric" ? "kg" : "lb"
        }
        if summary.metric.id == "bodyTemperature" {
            return unitSystem == "metric" ? "°C" : "°F"
        }
        return summary.metric.unit
    }

    private var formattedValue: String {
        guard let v = summary.latest?.value else { return "—" }
        switch summary.metric.id {
        case "sleep":
            let hours = Int(v)
            let minutes = Int((v - Double(hours)) * 60)
            return "\(hours)h \(minutes)m"
        case "restingHR":
            return "\(Int(v.rounded()))"
        case "steps":
            return v.formatted(.number)
        case "weight":
            // Service returns kg; convert when user pref is imperial.
            let display = unitSystem == "metric" ? v : v * 2.20462
            return String(format: "%.1f", display)
        case "hrv":
            // SDNN reads as an integer in HK; sub-ms precision is
            // noise on a sparkline.
            return "\(Int(v.rounded()))"
        case "bloodPressure":
            // Paired systolic / diastolic. `.value` carries systolic,
            // `.secondary` carries diastolic — populated by the
            // correlation fetcher in HealthDashboardService. Fallback
            // to a single value if diastolic is unexpectedly absent.
            let sys = Int(v.rounded())
            if let dia = summary.latest?.secondary {
                return "\(sys)/\(Int(dia.rounded()))"
            }
            return "\(sys)"
        case "spo2":
            // HK reports oxygenSaturation as a fraction (0.0–1.0);
            // multiply for percentage display. One decimal — Watch
            // SpO2 readings are stable enough to read as e.g. 97.5%.
            return String(format: "%.1f", v * 100)
        case "respiratoryRate":
            // Adult resting RR clusters around 12–20; one decimal so
            // the value isn't visually pinned to "12 → 13" jumps.
            return String(format: "%.1f", v)
        case "bodyTemperature":
            // Service stores °C from HK; convert when user pref is
            // imperial. One decimal — both °C and °F change in
            // tenths around a meaningful range.
            let display = unitSystem == "metric" ? v : v * 9/5 + 32
            return String(format: "%.1f", display)
        default:
            return v.formatted(.number)
        }
    }
}

// MARK: - Sparkline subviews

// Smoothed line — resting HR (7d) and weight (30d). Catmull-Rom keeps
// the curve from looking jagged on sparse weight samples without
// over-smoothing dense daily HR readings.
private struct LineSparkline: View {
    let samples: [MetricSample]
    let accent: Color

    var body: some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Date", sample.date),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(accent)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 44)
    }
}

// Bars per day — steps. Day-bucketed values from the service.
private struct BarSparkline: View {
    let samples: [MetricSample]
    let accent: Color

    var body: some View {
        Chart(samples) { sample in
            BarMark(
                x: .value("Date", sample.date, unit: .day),
                y: .value("Value", sample.value)
            )
            .foregroundStyle(accent)
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 44)
    }
}

// Two superimposed lines — used by Blood Pressure (systolic over
// diastolic). The secondary line reads at the same accent at lower
// alpha so the pair feels like one metric.
private struct DualLineSparkline: View {
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
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 44)
    }
}

// Sparse dots — used by Body Temperature (rarely sampled), and as the
// on-card variant for SpO2. Each sample renders as a single point;
// the eye fills in the trend without an over-confident smoothed line.
private struct DotSparkline: View {
    let samples: [MetricSample]
    let accent: Color

    var body: some View {
        Chart(samples) { sample in
            PointMark(
                x: .value("Date", sample.date),
                y: .value("Value", sample.value)
            )
            .foregroundStyle(accent)
            .symbolSize(28)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 44)
    }
}

// Stacked bar per night — sleep stages. Pre-iOS-16-style data only
// reports `asleepUnspecified`; in that case we drop in a single-color
// bar so old data still renders something sensible.
private struct SleepStackedSparkline: View {
    let samples: [MetricSample]

    private static let stageOrder = ["Core", "REM", "Deep"]

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                if let stages = sample.stages {
                    if isLegacyOnly(stages) {
                        BarMark(
                            x: .value("Night", sample.date, unit: .day),
                            y: .value("Hours", stages.unspecified / 3600.0)
                        )
                        .foregroundStyle(Color.emerald)
                        .cornerRadius(2)
                    } else {
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
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartForegroundStyleScale([
            "Core": Color.emerald.opacity(0.55),
            "REM":  Color.emerald.opacity(0.85),
            "Deep": Color.emerald,
        ])
        .frame(height: 44)
    }

    private func isLegacyOnly(_ stages: SleepStages) -> Bool {
        stages.unspecified > 0 && stages.core == 0 && stages.deep == 0 && stages.rem == 0
    }
}
