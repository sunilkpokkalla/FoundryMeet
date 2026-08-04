import Foundation

/// Where the Hub directory is scoped. Starts coarse (All / Near me / Remote)
/// and lets people drill into Country → City as the network grows.
enum HubLocationScope: String, Codable, CaseIterable, Identifiable {
    case nearMe
    case city
    case country
    case remote
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nearMe: return "Near me"
        case .city: return "City"
        case .country: return "Country"
        case .remote: return "Remote"
        case .all: return "All"
        }
    }

    var icon: String {
        switch self {
        case .nearMe: return "mappin.and.ellipse"
        case .city: return "building.2"
        case .country: return "globe"
        case .remote: return "wifi"
        case .all: return "square.grid.2x2"
        }
    }
}

struct HubLocationFilter: Equatable, Codable {
    var scope: HubLocationScope = .all
    /// Display country, e.g. "United States" or "Germany".
    var country: String? = nil
    /// Display city label from the network, e.g. "Austin, TX".
    var city: String? = nil

    static let `default` = HubLocationFilter()

    /// Chip label once a specific place is chosen.
    var selectionLabel: String? {
        switch scope {
        case .city:
            return city
        case .country:
            return country
        case .nearMe, .remote, .all:
            return nil
        }
    }
}

/// Best-effort split of freeform profile locations into city / country.
/// Handles "Austin, TX", "Berlin, Germany", and "Remote".
struct ParsedLocation: Equatable {
    var city: String?
    var region: String?
    var country: String?
    var isRemote: Bool
    var raw: String

    var cityLabel: String? {
        guard let city else { return nil }
        if let region, !region.isEmpty {
            return "\(city), \(region)"
        }
        if let country, country != "United States", !country.isEmpty {
            return "\(city), \(country)"
        }
        return city
    }
}

enum LocationParts {
    private static let usStateCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
    ]

    static func parse(_ value: String?) -> ParsedLocation {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else {
            return ParsedLocation(city: nil, region: nil, country: nil, isRemote: false, raw: raw)
        }

        if raw.lowercased() == "remote" {
            return ParsedLocation(city: nil, region: nil, country: nil, isRemote: true, raw: raw)
        }

        let parts = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else {
            return ParsedLocation(city: nil, region: nil, country: nil, isRemote: false, raw: raw)
        }

        if parts.count == 1 {
            return ParsedLocation(city: first, region: nil, country: nil, isRemote: false, raw: raw)
        }

        if parts.count == 2 {
            let second = parts[1]
            if usStateCodes.contains(second.uppercased()) {
                return ParsedLocation(
                    city: first,
                    region: second.uppercased(),
                    country: "United States",
                    isRemote: false,
                    raw: raw
                )
            }
            return ParsedLocation(
                city: first,
                region: nil,
                country: normalizeCountry(second),
                isRemote: false,
                raw: raw
            )
        }

        // "City, Region, Country"
        let region = parts[1]
        let country = normalizeCountry(parts[2])
        if usStateCodes.contains(region.uppercased()) {
            return ParsedLocation(
                city: first,
                region: region.uppercased(),
                country: "United States",
                isRemote: false,
                raw: raw
            )
        }
        return ParsedLocation(
            city: first,
            region: region,
            country: country,
            isRemote: false,
            raw: raw
        )
    }

    static func normalizeCountry(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "usa", "us", "u.s.", "u.s.a.", "united states of america":
            return "United States"
        case "uk", "u.k.", "great britain", "britain":
            return "United Kingdom"
        default:
            return trimmed
        }
    }

    static func isRemote(_ value: String?) -> Bool {
        parse(value).isRemote
    }

    static func matchesCountry(_ value: String?, country: String) -> Bool {
        guard let parsedCountry = parse(value).country else { return false }
        return parsedCountry.caseInsensitiveCompare(country) == .orderedSame
    }

    static func matchesCity(_ value: String?, cityLabel: String) -> Bool {
        if GeoDistance.isSameCity(value, cityLabel) { return true }
        let parsed = parse(value)
        let target = parse(cityLabel)
        guard
            let left = parsed.city?.lowercased(),
            let right = target.city?.lowercased(),
            left == right
        else { return false }
        // Springfield, IL must not match Springfield, MO.
        if let leftRegion = parsed.region, let rightRegion = target.region,
           leftRegion.caseInsensitiveCompare(rightRegion) != .orderedSame {
            return false
        }
        if let leftCountry = parsed.country, let rightCountry = target.country {
            return leftCountry.caseInsensitiveCompare(rightCountry) == .orderedSame
        }
        return true
    }
}

/// Cities / countries that already appear in the Hub directory.
struct HubPlaceOptions: Equatable {
    struct CityOption: Identifiable, Equatable, Hashable {
        var id: String { key }
        var key: String
        var label: String
        var country: String?
    }

    var countries: [String]
    var cities: [CityOption]

    static let empty = HubPlaceOptions(countries: [], cities: [])

    static func from(builders: [DiscoveryCandidate]) -> HubPlaceOptions {
        var countrySet = Set<String>()
        var cityMap: [String: CityOption] = [:]

        for builder in builders {
            let parsed = LocationParts.parse(builder.location)
            if parsed.isRemote { continue }

            if let country = parsed.country, !country.isEmpty {
                countrySet.insert(country)
            }

            if let label = parsed.cityLabel ?? builder.location?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !label.isEmpty,
               label.lowercased() != "remote" {
                let key = label.lowercased()
                if cityMap[key] == nil {
                    cityMap[key] = CityOption(
                        key: key,
                        label: label,
                        country: parsed.country
                    )
                }
            }
        }

        return HubPlaceOptions(
            countries: countrySet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
            cities: cityMap.values.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        )
    }

    func cities(in country: String?) -> [CityOption] {
        guard let country, !country.isEmpty else { return cities }
        return cities.filter {
            guard let cityCountry = $0.country else { return false }
            return cityCountry.caseInsensitiveCompare(country) == .orderedSame
        }
    }
}

enum HubLocationFilterStore {
    private static func key(for userId: String?) -> String {
        "hub_location_filter_\(userId ?? "default")"
    }

    static func load(userId: String?) -> HubLocationFilter {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: userId)),
            let filter = try? JSONDecoder().decode(HubLocationFilter.self, from: data)
        else {
            return .default
        }
        return filter
    }

    static func save(_ filter: HubLocationFilter, userId: String?) {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        UserDefaults.standard.set(data, forKey: key(for: userId))
    }
}

extension Array where Element == DiscoveryCandidate {
    func filtered(
        by locationFilter: HubLocationFilter,
        myLocation: String?,
        myLatitude: Double?,
        myLongitude: Double?
    ) -> [DiscoveryCandidate] {
        switch locationFilter.scope {
        case .all:
            return self
        case .remote:
            return self.filter { LocationParts.isRemote($0.location) }
        case .nearMe:
            return self.filter {
                if LocationParts.isRemote($0.location) { return false }
                return GeoDistance.isNearby(
                    myLocation: myLocation,
                    myLatitude: myLatitude,
                    myLongitude: myLongitude,
                    theirLocation: $0.location,
                    theirLatitude: $0.latitude,
                    theirLongitude: $0.longitude
                )
            }
        case .country:
            guard let country = locationFilter.country, !country.isEmpty else { return self }
            return self.filter { LocationParts.matchesCountry($0.location, country: country) }
        case .city:
            guard let city = locationFilter.city, !city.isEmpty else { return self }
            return self.filter { LocationParts.matchesCity($0.location, cityLabel: city) }
        }
    }
}
