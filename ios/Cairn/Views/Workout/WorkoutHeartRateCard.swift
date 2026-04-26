import SwiftUI

struct WorkoutHeartRateCard: View {
    let service: HeartRateService
    var userAge: Int = 25

    private var maxHR: Int { 220 - userAge }

    private func zoneColor(_ colorName: String) -> Color {
        switch colorName {
        case "gray": return .gray
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if service.currentBPM > 0 {
                liveHeartRateSection
                zoneBarSection
                zoneDurationsSection
                sessionStatsSection
            } else if service.isMonitoring {
                waitingState
            } else {
                unavailableState
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(14)
    }

    // MARK: - Live BPM + Zone

    private var liveHeartRateSection: some View {
        let zone = HeartRateZone.zone(for: service.currentBPM, maxHR: maxHR)
        return HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundColor(zoneColor(zone.color))
                .symbolEffect(.pulse, options: .repeating, value: service.currentBPM)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(service.currentBPM)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.ink)
                Text("BPM")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.slateText)
            }

            Spacer()

            Text(zone.name)
                .font(.caption.weight(.bold))
                .foregroundColor(Color.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(zoneColor(zone.color))
                .cornerRadius(8)
        }
    }

    // MARK: - Zone Position Bar

    private var zoneBarSection: some View {
        let zones = HeartRateZone.allZones(maxHR: maxHR)
        return GeometryReader { geo in
            let totalWidth = geo.size.width
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    ForEach(zones) { z in
                        let fraction = Double(z.maxBPM - z.minBPM) / Double(maxHR)
                        let currentZone = HeartRateZone.zone(for: service.currentBPM, maxHR: maxHR)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zoneColor(z.color).opacity(z.number == currentZone.number ? 1.0 : 0.3))
                            .frame(width: max(0, totalWidth * fraction - 2))
                    }
                }
                .frame(height: 10)

                let position = Double(service.currentBPM) / Double(maxHR)
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: min(totalWidth - 14, max(0, totalWidth * position - 7)))
            }
        }
        .frame(height: 14)
    }

    // MARK: - Zone Duration Breakdown

    private var zoneDurationsSection: some View {
        let durations = service.zoneDurations(maxHR: maxHR)
        let totalTime = durations.values.reduce(0, +)
        let zones = HeartRateZone.allZones(maxHR: maxHR)

        return VStack(spacing: 6) {
            HStack {
                Text("Zone Breakdown")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.slateText)
                Spacer()
            }

            ForEach(zones) { zone in
                let duration = durations[zone.number] ?? 0
                let fraction = totalTime > 0 ? duration / totalTime : 0

                HStack(spacing: 8) {
                    Text("Z\(zone.number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(zoneColor(zone.color))
                        .frame(width: 22, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.slateBorder)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(zoneColor(zone.color))
                                .frame(width: geo.size.width * fraction, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(formatDuration(duration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.slateText)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Session Stats

    private var sessionStatsSection: some View {
        HStack(spacing: 0) {
            statItem(label: "Avg", value: service.sessionAvgBPM > 0 ? "\(service.sessionAvgBPM)" : "--")
            Divider()
                .frame(height: 24)
                .overlay(Color.slateBorder)
            statItem(label: "Max", value: service.sessionMaxBPM > 0 ? "\(service.sessionMaxBPM)" : "--")
            Divider()
                .frame(height: 24)
                .overlay(Color.slateBorder)
            statItem(label: "Min", value: service.sessionMinBPM > 0 ? "\(service.sessionMinBPM)" : "--")
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.ink)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fallback States

    private var waitingState: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundColor(.slateText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Waiting for heart rate...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.ink)
                Text("Connect Apple Watch to see live data")
                    .font(.caption)
                    .foregroundColor(.slateText)
            }
            Spacer()
        }
    }

    private var unavailableState: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.slash")
                .font(.title2)
                .foregroundColor(.slateText)
            Text("Heart rate not available")
                .font(.subheadline)
                .foregroundColor(.slateText)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
