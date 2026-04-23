import WatchConnectivity
import Foundation

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var liveHeartRate: Double? = nil
    @Published var pendingWorkoutStart = false
    @Published var pendingWorkoutStop = false
    /// Workout-type string sent by the watch alongside `startWorkout`.
    /// ContentView reads this after `pendingWorkoutStart` fires so the
    /// iPhone session picks up the watch-selected type (running, cycling, …).
    @Published var pendingWorkoutType: String? = nil

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncoming(message)
        }
    }

    // Also handle messages delivered while Watch screen was off
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncoming(userInfo)
        }
    }

    /// Unified handler for messages from the watch. Both live sendMessage
    /// and queued transferUserInfo messages land here.
    private func handleIncoming(_ payload: [String: Any]) {
        if let action = payload["action"] as? String {
            switch action {
            case "startWorkout":
                pendingWorkoutStart = true
                // Captured for ContentView to apply after session.start().
                pendingWorkoutType = payload["type"] as? String
            case "stopWorkout":
                pendingWorkoutStop = true
            case "liveWorkoutData":
                applyLiveData(payload)
            case "finalWorkoutData":
                applyFinalData(payload)
            case "trackingFailed":
                // Watch couldn't start GPS tracking (HK auth missing, session
                // init failed, etc.). Clear the tracking flag so the save
                // flow doesn't wait 1.5s for data that will never arrive.
                let reason = (payload["reason"] as? String) ?? "unknown"
                print("[WatchConnectivity] watch GPS tracking failed: \(reason)")
                Task { @MainActor in
                    WorkoutSessionManager.shared.watchTrackingActive = false
                }
            default:
                break
            }
        }
        if let bpm = payload["heartRate"] as? Double {
            liveHeartRate = bpm
        }
    }

    /// Apply a throttled mid-workout update (distance + elevation) from
    /// the watch onto the active WorkoutSessionManager. Does nothing if
    /// no session is in progress. Hops to @MainActor because the session
    /// manager is main-actor-isolated.
    private func applyLiveData(_ payload: [String: Any]) {
        let distance = payload["distance"] as? Double
        let gain     = payload["elevationGain"] as? Double
        Task { @MainActor in
            let session = WorkoutSessionManager.shared
            guard session.isActive else { return }
            if let distance { session.liveDistanceMeters = distance; session.watchTrackingActive = true }
            if let gain     { session.liveElevationGain = gain }
        }
    }

    /// Apply the final payload sent at end-of-workout: distance, elevation,
    /// and the encoded route array. After this arrives the user typically
    /// just taps Save in the logger.
    private func applyFinalData(_ payload: [String: Any]) {
        let distance = payload["distance"] as? Double
        let gain     = payload["elevationGain"] as? Double
        let data     = payload["routeData"] as? Data
        Task { @MainActor in
            let session = WorkoutSessionManager.shared
            if let distance { session.liveDistanceMeters = distance }
            if let gain     { session.liveElevationGain = gain }
            if let data     { session.liveRouteData = data }
            session.watchTrackingActive = false
        }
    }

    /// Tell the Watch to stop its workout. Uses transferUserInfo as fallback when Watch screen is off.
    func sendStopWorkout() {
        guard WCSession.default.activationState == .activated else { return }
        let msg: [String: Any] = ["action": "stopWorkout"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }
}
