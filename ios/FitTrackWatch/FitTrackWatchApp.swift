import SwiftUI

@main
struct FitTrackWatchApp: App {
    @StateObject private var heartRateService = WatchHeartRateService.shared

    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(heartRateService)
        }
    }
}
