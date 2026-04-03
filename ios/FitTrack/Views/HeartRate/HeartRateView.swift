import SwiftUI
import HealthKit

struct HeartRateView: View {
    @StateObject private var viewModel = HeartRateViewModel()

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
        NavigationStack {
            List {
                currentHeartRateSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                zoneIndicatorSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                zonesSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                settingsSection
                    .listRowBackground(Color.slateBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Heart Rate")
            .task {
                await viewModel.setup()
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
        }
    }

    // MARK: - Current Heart Rate

    private var currentHeartRateSection: some View {
        VStack(spacing: 16) {
            if viewModel.isAuthorized {
                let zone = viewModel.currentZone
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(zoneColor(zone.color))
                        .symbolEffect(.pulse, options: .repeating, value: viewModel.service.currentBPM > 0)

                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.service.currentBPM > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(viewModel.service.currentBPM)")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("BPM")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.slateText)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.slateText)
                            Text("Waiting for data...")
                                .font(.subheadline)
                                .foregroundColor(.slateText)
                        }
                    }

                    Spacer()
                }

                if viewModel.service.currentBPM > 0 {
                    Text("Last updated: \(viewModel.lastUpdatedString)")
                        .font(.caption)
                        .foregroundColor(.slateText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.slateText)

                    Text("Heart Rate Access Required")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Grant HealthKit access to see your Apple Watch heart rate data.")
                        .font(.subheadline)
                        .foregroundColor(.slateText)
                        .multilineTextAlignment(.center)

                    Button("Enable Access") {
                        Task { await viewModel.requestAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.emerald)
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Zone Indicator

    private var zoneIndicatorSection: some View {
        VStack(spacing: 12) {
            if viewModel.service.currentBPM > 0 {
                let zone = viewModel.currentZone

                HStack {
                    Text("Current Zone")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.slateText)
                    Spacer()
                    Text(zone.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(zoneColor(zone.color))
                }

                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let zones = HeartRateZone.allZones(maxHR: viewModel.maxHeartRate)

                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(zones) { z in
                                let fraction = Double(z.maxBPM - z.minBPM) / Double(viewModel.maxHeartRate)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(zoneColor(z.color).opacity(z.number == zone.number ? 1.0 : 0.3))
                                    .frame(width: max(0, totalWidth * fraction - 2))
                            }
                        }
                        .frame(height: 12)

                        let position = Double(viewModel.service.currentBPM) / Double(viewModel.maxHeartRate)
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: min(totalWidth - 16, max(0, totalWidth * position - 8)))
                    }
                }
                .frame(height: 16)

                Text(zone.description)
                    .font(.caption)
                    .foregroundColor(.slateText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Zones Breakdown

    private var zonesSection: some View {
        VStack(spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(HeartRateZone.allZones(maxHR: viewModel.maxHeartRate)) { zone in
                HStack(spacing: 12) {
                    Circle()
                        .fill(zoneColor(zone.color))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zone \(zone.number): \(zone.name)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(viewModel.currentZone.number == zone.number ? zoneColor(zone.color) : .white)
                        Text(zone.description)
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }

                    Spacer()

                    Text("\(zone.minBPM)–\(zone.maxBPM)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(viewModel.currentZone.number == zone.number ? zoneColor(zone.color) : .slateText)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Age")
                    .foregroundColor(.white)
                Spacer()
                TextField("Age", value: $viewModel.userAge, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.emerald)
                    .frame(width: 60)
            }

            HStack {
                Text("Max Heart Rate")
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.maxHeartRate) BPM")
                    .foregroundColor(.slateText)
            }

            Text("Max HR = 220 - age. Zones are calculated from this value.")
                .font(.caption)
                .foregroundColor(.slateText)
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(16)
    }
}

// MARK: - View Model (delegates to shared HeartRateService)

@MainActor
class HeartRateViewModel: ObservableObject {
    let service = HeartRateService()
    @Published var isAuthorized = false
    @Published var userAge: Int = 25 {
        didSet {
            UserDefaults.standard.set(userAge, forKey: "heartRateUserAge")
        }
    }

    var maxHeartRate: Int { 220 - userAge }

    var currentZone: HeartRateZone {
        HeartRateZone.zone(for: service.currentBPM, maxHR: maxHeartRate)
    }

    var lastUpdatedString: String {
        guard let date = service.lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func setup() async {
        userAge = UserDefaults.standard.integer(forKey: "heartRateUserAge")
        if userAge == 0 { userAge = 25 }

        guard HealthKitManager.shared.isAvailable else { return }
        let authorized = await HealthKitManager.shared.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            await service.startMonitoring()
        }
    }

    func requestAccess() async {
        let authorized = await HealthKitManager.shared.requestAuthorization()
        isAuthorized = authorized
        if authorized {
            await service.startMonitoring()
        }
    }

    func stopMonitoring() {
        service.stopMonitoring()
    }
}

#Preview {
    HeartRateView()
}
