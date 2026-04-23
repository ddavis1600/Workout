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
    func start(activityType: HKWorkoutActivityType) {
        guard !isActive else { return }
        reset()
        self.activityType = activityType

        // HKWorkoutSession keeps the watch awake for HR sampling even when
        // the screen is off. We deliberately DON'T call
        // builder.finishWorkout at the end — the iPhone writes the workout
        // so there's only one record in Apple Health.
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType  = Self.usesGPS(activityType) ? .outdoor : .indoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
            self.workoutSession = session
            self.liveBuilder = builder
        } catch {
            print("[WatchWorkoutSession] HKWorkoutSession start failed: \(error)")
            // Non-fatal — location tracking can still work without it.
        }

        if Self.usesGPS(activityType) {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }

        isActive = true
    }

    /// End the workout. Discards the HKLiveWorkoutBuilder (we don't write to
    /// HealthKit on the watch) and sends the final payload to the iPhone.
    func stop() {
        guard isActive else { return }
        isActive = false

        locationManager.stopUpdatingLocation()

        if let session = workoutSession {
            session.end()
        }
        if let builder = liveBuilder {
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
