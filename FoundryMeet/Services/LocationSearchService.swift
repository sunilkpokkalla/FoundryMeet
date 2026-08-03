import Foundation
import MapKit

/// A city the user can pick, plus coordinates when we managed to resolve them.
/// Free text typed by hand is still a valid place, just without coordinates.
struct ResolvedPlace: Codable, Equatable {
    var displayName: String
    var latitude: Double?
    var longitude: Double?

    static let remote = ResolvedPlace(displayName: "Remote")

    var hasCoordinates: Bool { latitude != nil && longitude != nil }

    init(displayName: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// One row in the autocomplete list. Deliberately plain so it can cross actor
/// boundaries; MapKit's own completion objects cannot.
struct LocationSuggestion: Identifiable, Equatable, Sendable {
    var id: String { "\(title)|\(subtitle)" }
    let title: String
    let subtitle: String

    var query: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

@MainActor
final class LocationSearchService: NSObject, ObservableObject {
    @Published private(set) var suggestions: [LocationSuggestion] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    func updateQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
        isSearching = false
    }

    /// Turns a tapped suggestion into a tidy name plus coordinates. Falls back to
    /// the suggestion's own text if the lookup comes back empty.
    func resolve(_ suggestion: LocationSuggestion) async -> ResolvedPlace {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = suggestion.query
        request.resultTypes = .address

        guard
            let response = try? await MKLocalSearch(request: request).start(),
            let placemark = response.mapItems.first?.placemark
        else {
            return ResolvedPlace(displayName: suggestion.query)
        }

        let name = LocationFormatter.displayName(
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea,
            country: placemark.country
        )
        return ResolvedPlace(
            displayName: name.isEmpty ? suggestion.query : name,
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results
            .map { LocationSuggestion(title: $0.title, subtitle: $0.subtitle) }
            .filter { LocationFormatter.isLikelyPlace(title: $0.title) }
        Task { @MainActor in
            self.suggestions = LocationFormatter.deduplicate(mapped)
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}

enum LocationFormatter {
    /// "San Francisco, CA" at home, "Berlin, Germany" everywhere else — the
    /// shape people expect to read in each case.
    static func displayName(
        locality: String?,
        administrativeArea: String?,
        country: String?
    ) -> String {
        let city = trimmed(locality)
        let region = trimmed(administrativeArea)
        let nation = trimmed(country)

        let isUnitedStates = nation == "United States" || nation == "United States of America"
        let secondPart = isUnitedStates ? (region ?? nation) : (nation ?? region)

        return [city ?? region ?? nation, city == nil ? nil : secondPart]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// Street addresses come back from the same query as cities; a leading house
    /// number is the cheapest way to tell them apart.
    static func isLikelyPlace(title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard let first = trimmedTitle.first else { return false }
        return !first.isNumber
    }

    static func deduplicate(_ suggestions: [LocationSuggestion]) -> [LocationSuggestion] {
        var seen = Set<String>()
        return suggestions.filter { seen.insert($0.id).inserted }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
