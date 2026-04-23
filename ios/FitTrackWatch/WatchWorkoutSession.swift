import Foundation
import CoreLocation
import HealthKit

/// One sample from the CoreLocation stream. Encoded to JSON and sent to
/// the iPhone at end-of-workout — matches Workout.RoutePoint on the
/// iPhone side (both share the `lat / lon / alt / t` shape).
struct WatchRoutePoint: Codable {
    let lat: Double
    let lon: Double
    let alt: Double?
    let t: TimeInterval
}

/// Manages a live outdoor workout on the watch: starts an HKWorkoutSession
/// (for background sensor time), runs CLLocationManager for GPS, accumulates
/// distance + elevation gain, buffers the route, and streams updates to the
/// iPhone via WatchConnectivity. The iPhone writes the workout to HealthKit
/// — the watch just collects data.
///
/// Background operation: CLLocationManager.allowsBackgroundLocationUpdates
/// keeps locations flowing while the watch screen is off. Requires
/// `UIBackgroundModes: ["location"]` in the watch Info.plist and the
/// location-when-in-use permission (requested at start).
@MainActor
final class WatchWorkoutSession: NSObject, ObservableObject {
    static let shared = WatchWorkoutSession()

    // MARK: - Published state
    @Published var isActive: Bool = false
    @Published var activityType: HKWorkoutActivityType = .traditionalStrengthTraining
    @Published var currentDistanceMeters: Double = 0
    @Published var currentElevationGain: Double = 0
    @Published var hasFirstFix: Bool = false
    /// Last error message, for display in the watch UI. nil when healthy.
    @Published var errorMessage: String? = nil

    // MARK: - Private state
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var liveBuilder: HKLiveWorkoutBuilder?

    private lazy var locationManager: CLLocationManager = {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyBest
        m.activityType = .fitness
        m.distanceFilter = 5         // metres — ignore jitter below this
        m.allowsBackgroundLocationUpdates = true
        return m
    }()

    private var routeLocations: [CLLocation] = []
    private var lastLocation: CLLocation?
    private var lastLiveUpdateSent: Date = .distantPast

    override init() { super.init() }

    // MARK: - Lifecycle

    /// Whether this activity type uses GPS tracking. Strength / HIIT / yoga
    /// keep the workout session (for HR background time) but skip location.
    static func usesGPS(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .running, .walking, .hiking, .cycling, .swimming:
            return true
        default:
            return false
        }
    }

    /// Start a workout. Safe to call with any activity type — GPS is only
    /// enabled for distance activities.
    ///
    /// Flow (fixing the "watch app shuts down mid-workout" bug):
    ///   1. Request HealthKit authorization for HKWorkoutType.workoutType()
    ///      plus the distance quantity types we'd emit samples against.
    ///      Without this share permission, `HKWorkoutSession.init` throws
    ///      and the session never actually runs — which means watchOS
    ///      grants NO background runtime, CLLocationManager's
    ///      allowsBackgroundLocationUpdates has no effect, and the app is
    ///      suspended the moment the screen turns off.
    ///   2. Once authorized, create the HKWorkoutSession + builder and
    ///      start them. Only now does `workout-processing` in
    ///      WKBackgroundModes actually provide background time.
    ///   3. For GPS activities, start CLLocationManager. We rely on the
    ///      active HKWorkoutSession to keep the process alive.
    func start(activityType: HKWorkoutActivityType) {
        guard !isActive else { return }
        reset()
        self.activityType = activityType

        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.activeEnergyBurned),
        ]
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = "Health access error: \(error.localizedDescription)"
                    self.notifyPhoneTrackingFailed(reason: "auth-error")
                    return
                }
                guard granted else {
                    self.errorMessage = "Health access denied — grant workout permission in Settings."
                    self.notifyPhoneTrackingFailed(reason: "auth-denied")
                    return
                }
                self.beginSession(activityType: activityType)
            }
        }
    }

    /// Actually start the session after auth is confirmed.
    private func beginSession(activityType: HKWorkoutActivityType) {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType  = Self.usesGPS(activityType) ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                if let error {
                    print("[WatchWorkoutSession] beginCollection failed: \(error)")
                }
                _ = success
            }
            self.workoutSession = session
            self.liveBuilder = builder
            self.isActive = true

            if Self.usesGPS(activityType) {
                locationManager.requestWhenInUseAuthorization()
                locationManager.startUpdatingLocation()
            }
        } catch {
            print("[WatchWorkoutSession] HKWorkoutSession start failed: \(error)")
            errorMessage = "Could not start workout session: \(error.localizedDescription)"
            notifyPhoneTrackingFailed(reason: "session-init-failed")
        }
    }

    /// Tell the iPhone we couldn't start GPS tracking so its LogWorkoutView
    /// doesn't sit waiting for liveWorkoutData messages that will never
    /// arrive — and its save flow doesn't pause for the 1.5s watch-stop
    /// window either.
    private func notifyPhoneTrackingFailed(reason: String) {
        WatchSessionManager.shared.sendMessage([
            "action": "trackingFailed",
            "reason": reason,
        ])
    }

    /// End the workout. Discards the HKLiveWorkoutBuilder (we don't write to
    /// HealthKit on the watch) and sends the final payload to the iPhone.
    func stop() {
        guard isActive else { return }
        isActive = false

        locationManager.stopUpdatingLocation()

        if let session = workoutSession {
            session.delegate = nil
            session.end()
        }
        if let builder = liveBuilder {
            builder.delegate = nil
            builder.endCollection(withEnd: Date()) { _, _ in }
            // No finishWorkout — the iPhone is the source of truth.
            builder.discardWorkout()
        }
        workoutSession = nil
        liveBuilder = nil

        sendFinalPayloadToPhone()
    }

    private func reset() {
        currentDistanceMeters = 0
        currentElevationGain = 0
        routeLocations = []
        lastLocation = nil
        hasFirstFix = false
        lastLiveUpdateSent = .distantPast
    }

    // MARK: - Phone messaging

    /// Throttled live update (≈ every 5s) while the workout is in progress.
    private func sendLiveUpdateIfDue() {
        guard Date().timeIntervalSince(lastLiveUpdateSent) >= 5.0 else { return }
        lastLiveUpdateSent = Date()
        WatchSessionManager.shared.sendMessage([
            "action":        "liveWorkoutData",
            "distance":      currentDistanceMeters,
            "elevationGain": currentElevationGain,
        ])
    }

    /// Final workout data sent at stop — includes the encoded route array.
    private func sendFinalPayloadToPhone() {
        let points = routeLocations.map {
            WatchRoutePoint(
                lat: $0.coordinate.latitude,
                lon: $0.coordinate.longitude,
                alt: $0.verticalAccuracy >= 0 ? $0.altitude : nil,
                t:   $0.timestamp.timeIntervalSince1970
            )
        }
        var msg: [String: Any] = [
            "action":        "finalWorkoutData",
            "distance":      currentDistanceMeters,
            "elevationGain": currentElevationGain,
        ]
        if let data = try? JSONEncoder().encode(points) {
            msg["routeData"] = data
        }
        WatchSessionManager.shared.sendMessage(msg)
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchWorkoutSession: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                // Filter out bad fixes — keeps distance math honest.
                guard location.horizontalAccuracy > 0,
                      location.horizontalAccuracy < 50 else { continue }

                if let last = self.lastLocation {
                    let delta = location.distance(from: last)
                    // Ignore sub-metre jitter
                    if delta >= 1 {
                        self.currentDistanceMeters += delta
                        // Elevation: only accumulate positive gains and
                        // ignore implausibly large jumps (>50m in one step).
                        if location.verticalAccuracy >= 0, last.verticalAccuracy >= 0 {
                            let altDelta = location.altitude - last.altitude
                            if altDelta > 0, altDelta < 50 {
                                self.currentElevationGain += altDelta
                            }
                        }
                    }
                }
                self.routeLocations.append(location)
                self.lastLocation = location
                self.hasFirstFix = true
            }

            self.sendLiveUpdateIfDue()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal — CoreLocation will retry.
        print("[WatchWorkoutSession] location error: \(error)")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        print("[WatchWorkoutSession] state: \(fromState.rawValue) → \(toState.rawValue)")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("[WatchWorkoutSession] session failed: \(error)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Session dying without our say-so means watchOS killed it — we
            // tell the phone to stop waiting and surface the error locally.
            self.errorMessage = "Session ended unexpectedly: \(error.localizedDescription)"
            self.notifyPhoneTrackingFailed(reason: "session-failed")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
// Required for the builder's data source even though we never write —
// without a delegate the builder logs warnings and may skip some sensor
// setup paths.

extension WatchWorkoutSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // HR is streamed separately via WatchHeartRateService — ignore.
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // We don't use workout events (lap / pause markers) — ignore.
    }
}
