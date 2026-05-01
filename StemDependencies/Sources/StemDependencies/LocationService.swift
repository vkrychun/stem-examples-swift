//
//  LocationService.swift
//  StemDependencies
//
//  Reference implementation of a custom `StemService` external to StemRuntimeSDK.
//  Demonstrates how a host app can extend StemJSON with native capabilities —
//  here, one-shot access to the device's current coordinates — that the DSL
//  can then consume via a `service` action.
//
//  Usage
//  -----
//  1. Register once at host startup:
//
//         renderer.register(LocationService.self, as: AppServiceType.location)
//
//  2. In JSON, declare the service as a module dependency and invoke it:
//
//         "dependencies": [
//           { "service": { "location": { "id": "dep_location" } } }
//         ]
//
//         "events": { "onTap": [
//           { "service": { "id": "act_get_location",
//                          "input": { "serviceId": "dep_location" },
//                          "output": { "success": [
//                            { "state": { "id": "act_save",
//                                "input": { "lat":      "@{act_get_location.latitude}",
//                                           "lng":      "@{act_get_location.longitude}",
//                                           "accuracy": "@{act_get_location.accuracy}" } } }
//                          ] } } }
//         ] }
//
//  The service returns a dictionary: `latitude`, `longitude`, `altitude`,
//  `accuracy` (horizontal, metres), `timestamp` (ISO 8601).
//
//  Permissions
//  -----------
//  Host app must declare `NSLocationWhenInUseUsageDescription` in its
//  Info.plist. The service requests When-In-Use authorization on first call
//  and surfaces the system prompt to the user.

import CoreLocation
import StemRuntimeSDK

public final class LocationService: NSObject, StemService, Decodable, @unchecked Sendable {

    public let id: String

    private var locationManager: CLLocationManager!
    private var locationContinuation: CheckedContinuation<[String: Any], any Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private enum CodingKeys: String, CodingKey { case id }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        super.init()
    }

    /// CLLocationManager must be created on the main thread — delegate callbacks
    /// are delivered on the run loop of the creating thread, and background
    /// threads spawned during JSON decoding have no active run loop.
    @MainActor
    private func ensureLocationManager() {
        guard locationManager == nil else { return }
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }

    @MainActor
    public func execute(_ input: Any?) async throws(StemActionError) -> Any? {
        ensureLocationManager()
        let status = await resolveAuthorization()

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw StemActionError(.network(.notAuthorized), "Location permission not granted")
        }

        do {
            let result: [String: Any] = try await withCheckedThrowingContinuation { continuation in
                self.locationContinuation = continuation
                self.locationManager.requestLocation()

                // Timeout: cancel after 15 seconds if no callback received.
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(15))
                    guard let self, let pending = self.locationContinuation else { return }
                    self.locationContinuation = nil
                    pending.resume(throwing: StemActionError(.general(.timeout), "Location request timed out"))
                }
            }
            return result
        } catch let error as StemActionError {
            throw error
        } catch {
            throw StemActionError(error)
        }
    }

    @MainActor
    private func resolveAuthorization() async -> CLAuthorizationStatus {
        let current = locationManager.authorizationStatus
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        authContinuation?.resume(returning: status)
        authContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let result: [String: Any] = [
            "latitude":  location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude":  location.altitude,
            "accuracy":  location.horizontalAccuracy,
            "timestamp": ISO8601DateFormatter().string(from: location.timestamp)
        ]
        locationContinuation?.resume(returning: result)
        locationContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
