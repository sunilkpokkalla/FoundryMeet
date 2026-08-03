import Foundation

/// Rough distance helpers for coffee-chat proximity. Exact meters do not matter;
/// same metro vs another coast does.
enum GeoDistance {
    /// About an hour's drive / same metro — far enough to be useful, tight
    /// enough that a coffee is still plausible.
    static let nearbyKilometers = 80.0

    static func kilometers(
        from origin: (latitude: Double, longitude: Double),
        to destination: (latitude: Double, longitude: Double)
    ) -> Double {
        let earthRadiusKm = 6371.0
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let dLat = (destination.latitude - origin.latitude) * .pi / 180
        let dLon = (destination.longitude - origin.longitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    static func isSameCity(_ lhs: String?, _ rhs: String?) -> Bool {
        guard
            let left = normalizedCity(lhs),
            let right = normalizedCity(rhs)
        else { return false }
        return left == right
    }

    static func normalizedCity(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty || trimmed == "remote" ? nil : trimmed
    }

    /// Prefer coordinate distance; fall back to city-name equality.
    static func isNearby(
        myLocation: String?,
        myLatitude: Double?,
        myLongitude: Double?,
        theirLocation: String?,
        theirLatitude: Double?,
        theirLongitude: Double?
    ) -> Bool {
        if let mineLat = myLatitude, let mineLon = myLongitude,
           let theirsLat = theirLatitude, let theirsLon = theirLongitude {
            return kilometers(
                from: (mineLat, mineLon),
                to: (theirsLat, theirsLon)
            ) <= nearbyKilometers
        }
        return isSameCity(myLocation, theirLocation)
    }

    /// Smaller is closer. Missing geometry sorts last.
    static func sortKeyKilometers(
        myLatitude: Double?,
        myLongitude: Double?,
        theirLatitude: Double?,
        theirLongitude: Double?,
        myLocation: String?,
        theirLocation: String?
    ) -> Double {
        if let mineLat = myLatitude, let mineLon = myLongitude,
           let theirsLat = theirLatitude, let theirsLon = theirLongitude {
            return kilometers(from: (mineLat, mineLon), to: (theirsLat, theirsLon))
        }
        if isSameCity(myLocation, theirLocation) { return 0 }
        return .greatestFiniteMagnitude
    }
}
