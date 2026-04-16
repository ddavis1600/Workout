import SwiftUI

@main
struct FitTrackWatchApp: App {
    @StateObject private var heartRateService = WatchHeartRateService()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(heartRateService)
        }
    }
}
