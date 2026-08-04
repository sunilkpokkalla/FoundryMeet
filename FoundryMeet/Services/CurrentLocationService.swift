import CoreLocation
import Foundation

/// One-shot when-in-use location → city-level `ResolvedPlace` for profiles and Near me.
@MainActor
final class CurrentLocationService: NSObject, ObservableObject {
    enum ServiceError: LocalizedError {
        case denied
        case unavailable
        case timedOut
        case geocodeFailed

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access is off. Enable it in Settings to use your current city."
            case .unavailable:
                return "Couldn't read your current location. Try again."
            case .timedOut:
                return "Finding your location took too long. Try again."
            case .geocodeFailed:
                return "Found your coordinates, but couldn't name the city."
            }
        }
    }

    @Published private(set) var isLocating = false

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationRequestID = UUID()

    override init() {
        super.init()
        manager.delegate = self
        // City / metro accuracy is enough for coffee-chat proximity.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Asks for when-in-use permission if needed, reads GPS once, reverse-geocodes to a city.
    func fetchCurrentPlace() async throws -> ResolvedPlace {
        isLocating = true
        defer { isLocating = false }

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            let updated = await requestAuthorization()
            guard updated == .authorizedWhenInUse || updated == .authorizedAlways else {
                throw ServiceError.denied
            }
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .denied, .restricted:
            throw ServiceError.denied
        @unknown default:
            throw ServiceError.unavailable
        }

        guard CLLocationManager.locationServicesEnabled() else {
            throw ServiceError.unavailable
        }

        let location = try await requestLocation()
        return try await reverseGeocode(location)
    }

    private func requestAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        let requestID = UUID()
        locationRequestID = requestID
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, self.locationRequestID == requestID else { return }
                guard let pending = self.locationContinuation else { return }
                self.locationContinuation = nil
                pending.resume(throwing: ServiceError.timedOut)
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> ResolvedPlace {
        let geocoder = CLGeocoder()
        let marks = try await geocoder.reverseGeocodeLocation(location)
        guard let mark = marks.first else { throw ServiceError.geocodeFailed }

        let name = LocationFormatter.displayName(
            locality: mark.locality,
            administrativeArea: mark.administrativeArea,
            country: mark.country
        )
        let display = name.isEmpty
            ? (mark.name ?? "Current location")
            : name

        return ResolvedPlace(
            displayName: display,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

extension CurrentLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            authorizationContinuation?.resume(returning: status)
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: ServiceError.unavailable)
            locationContinuation = nil
        }
    }
}
