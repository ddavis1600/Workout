import SwiftUI
import WatchConnectivity

struct WatchContentView: View {
    @EnvironmentObject var service: WatchHeartRateService
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                // BPM display
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(service.currentBPM > 0 ? "\(service.currentBPM)" : "–")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(zoneColor)
                    Text("BPM")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }

                // Zone label
                if service.currentBPM > 0 {
                    Text(service.zoneName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(zoneColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(zoneColor.opacity(0.2))
                        .clipShape(Capsule())
                }

                // Start / Stop button
                Button {
                    if service.isMonitoring {
                        service.stopMonitoring()
                        WatchSessionManager.shared.sendStopWorkout()
                    } else {
                        service.startMonitoring()
                        WatchSessionManager.shared.sendMessage(["action": "startWorkout", "type": "Workout"])
                    }
                } label: {
                    Label(
                        service.isMonitoring ? "Stop" : "Start",
                        systemImage: service.isMonitoring ? "stop.fill" : "heart.fill"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(service.isMonitoring ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Last updated
                if let updated = service.lastUpdated {
                    Text(updated, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        // iPhone finished/cancelled the workout — stop monitoring on Watch too
        .onChange(of: sessionManager.pendingStop) { stop in
            if stop {
                service.stopMonitoring()
                sessionManager.pendingStop = false
            }
        }
    }

    private var zoneColor: Color {
        switch service.zoneColor {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }
}
