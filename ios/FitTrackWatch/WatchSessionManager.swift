import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var pendingStop = false

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    // Handle real-time messages from iPhone (Watch screen on)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String, action == "stopWorkout" {
                self.pendingStop = true
            }
        }
    }

    // Handle queued messages delivered when Watch wakes
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            if let action = userInfo["action"] as? String, action == "stopWorkout" {
                self.pendingStop = true
            }
        }
    }

    /// Send a message to iPhone. Falls back to transferUserInfo when not immediately reachable.
    func sendMessage(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    func sendStopWorkout() {
        sendMessage(["action": "stopWorkout"])
    }
}
