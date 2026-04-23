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
            if let action = message["action"] as? String {
                if action == "startWorkout" {
                    self.pendingWorkoutStart = true
                    // Capture the watch-selected type so ContentView can
                    // apply it to the iPhone session when it opens the logger.
                    self.pendingWorkoutType = message["type"] as? String
                }
                if action == "stopWorkout"  { self.pendingWorkoutStop  = true }
            }
            if let bpm = message["heartRate"] as? Double {
                self.liveHeartRate = bpm
            }
        }
    }

    // Also handle messages delivered while Watch screen was off
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            if let action = userInfo["action"] as? String {
                if action == "startWorkout" {
                    self.pendingWorkoutStart = true
                    self.pendingWorkoutType = userInfo["type"] as? String
                }
                if action == "stopWorkout"  { self.pendingWorkoutStop  = true }
            }
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
