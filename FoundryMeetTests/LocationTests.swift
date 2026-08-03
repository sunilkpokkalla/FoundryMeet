import XCTest
@testable import FoundryMeet

final class LocationFormatterTests: XCTestCase {
    func testUnitedStatesUsesStateNotCountry() {
        XCTAssertEqual(
            LocationFormatter.displayName(
                locality: "San Francisco",
                administrativeArea: "CA",
                country: "United States"
            ),
            "San Francisco, CA"
        )
    }

    func testElsewhereUsesCountryNotRegion() {
        XCTAssertEqual(
            LocationFormatter.displayName(
                locality: "Berlin",
                administrativeArea: "Berlin",
                country: "Germany"
            ),
            "Berlin, Germany"
        )
        XCTAssertEqual(
            LocationFormatter.displayName(
                locality: "Bangalore",
                administrativeArea: "Karnataka",
                country: "India"
            ),
            "Bangalore, India"
        )
    }

    func testFallsBackWhenPartsAreMissing() {
        XCTAssertEqual(
            LocationFormatter.displayName(locality: "Austin", administrativeArea: nil, country: nil),
            "Austin"
        )
        XCTAssertEqual(
            LocationFormatter.displayName(locality: nil, administrativeArea: nil, country: "Japan"),
            "Japan"
        )
        XCTAssertEqual(
            LocationFormatter.displayName(locality: nil, administrativeArea: nil, country: nil),
            ""
        )
    }

    func testBlankPartsAreIgnored() {
        XCTAssertEqual(
            LocationFormatter.displayName(locality: "  ", administrativeArea: "CA", country: "United States"),
            "CA"
        )
    }

    func testStreetAddressesAreFilteredOut() {
        XCTAssertFalse(LocationFormatter.isLikelyPlace(title: "500 Howard St"))
        XCTAssertFalse(LocationFormatter.isLikelyPlace(title: ""))
        XCTAssertTrue(LocationFormatter.isLikelyPlace(title: "San Francisco"))
        XCTAssertTrue(LocationFormatter.isLikelyPlace(title: "Île-de-France"))
    }

    func testDuplicateSuggestionsCollapse() {
        let suggestions = [
            LocationSuggestion(title: "Austin", subtitle: "TX, United States"),
            LocationSuggestion(title: "Austin", subtitle: "TX, United States"),
            LocationSuggestion(title: "Austin", subtitle: "MN, United States")
        ]
        XCTAssertEqual(LocationFormatter.deduplicate(suggestions).count, 2)
    }
}

final class ResolvedPlaceTests: XCTestCase {
    func testFreeTextHasNoCoordinates() {
        let typed = ResolvedPlace(displayName: "Somewhere small")
        XCTAssertFalse(typed.hasCoordinates)
    }

    func testRemoteIsCoordinateFree() {
        XCTAssertEqual(ResolvedPlace.remote.displayName, "Remote")
        XCTAssertFalse(ResolvedPlace.remote.hasCoordinates)
    }

    func testPickedPlaceKeepsCoordinates() {
        let picked = ResolvedPlace(displayName: "San Francisco, CA", latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(picked.hasCoordinates)
    }

    func testProfileExposesItsPlace() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        XCTAssertNil(profile.place, "A profile with no location has no place")

        profile.location = "San Francisco, CA"
        profile.latitude = 37.7749
        profile.longitude = -122.4194
        XCTAssertEqual(profile.place?.displayName, "San Francisco, CA")
        XCTAssertTrue(profile.place?.hasCoordinates == true)
    }

    func testCoordinatesSurviveTheFirestoreRoundTrip() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        profile.location = "Berlin, Germany"
        profile.latitude = 52.52
        profile.longitude = 13.405

        let restored = UserProfile(id: "u1", firestoreData: profile.firestoreData)
        XCTAssertEqual(restored.location, "Berlin, Germany")
        XCTAssertEqual(restored.latitude, 52.52)
        XCTAssertEqual(restored.longitude, 13.405)
    }

    func testTypedLocationRoundTripsWithoutCoordinates() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        profile.location = "Remote"

        let restored = UserProfile(id: "u1", firestoreData: profile.firestoreData)
        XCTAssertEqual(restored.location, "Remote")
        XCTAssertNil(restored.latitude)
        XCTAssertNil(restored.longitude)
    }
}

final class LocationPartsTests: XCTestCase {
    func testParsesUSCityAndState() {
        let parsed = LocationParts.parse("Austin, TX")
        XCTAssertEqual(parsed.city, "Austin")
        XCTAssertEqual(parsed.region, "TX")
        XCTAssertEqual(parsed.country, "United States")
        XCTAssertEqual(parsed.cityLabel, "Austin, TX")
        XCTAssertFalse(parsed.isRemote)
    }

    func testParsesInternationalCity() {
        let parsed = LocationParts.parse("Berlin, Germany")
        XCTAssertEqual(parsed.city, "Berlin")
        XCTAssertEqual(parsed.country, "Germany")
        XCTAssertEqual(parsed.cityLabel, "Berlin, Germany")
    }

    func testParsesRemote() {
        XCTAssertTrue(LocationParts.parse("Remote").isRemote)
        XCTAssertTrue(LocationParts.isRemote("remote"))
    }

    func testCountryAndCityMatching() {
        XCTAssertTrue(LocationParts.matchesCountry("Austin, TX", country: "United States"))
        XCTAssertTrue(LocationParts.matchesCountry("Berlin, Germany", country: "Germany"))
        XCTAssertTrue(LocationParts.matchesCity("Austin, TX", cityLabel: "Austin, TX"))
        XCTAssertFalse(LocationParts.matchesCity("Austin, TX", cityLabel: "Berlin, Germany"))
    }

    func testHubFilterScopes() {
        let builders = [
            DiscoveryCandidate(
                id: "1", name: "A", role: "Founder", imgUrl: "", desc: "",
                tags: [], industry: "AI", location: "Austin, TX",
                latitude: 30.27, longitude: -97.74
            ),
            DiscoveryCandidate(
                id: "2", name: "B", role: "Founder", imgUrl: "", desc: "",
                tags: [], industry: "AI", location: "Berlin, Germany"
            ),
            DiscoveryCandidate(
                id: "3", name: "C", role: "Founder", imgUrl: "", desc: "",
                tags: [], industry: "AI", location: "Remote"
            )
        ]

        let remote = builders.filtered(
            by: HubLocationFilter(scope: .remote),
            myLocation: "Austin, TX",
            myLatitude: 30.27,
            myLongitude: -97.74
        )
        XCTAssertEqual(remote.map(\.id), ["3"])

        let country = builders.filtered(
            by: HubLocationFilter(scope: .country, country: "Germany"),
            myLocation: nil,
            myLatitude: nil,
            myLongitude: nil
        )
        XCTAssertEqual(country.map(\.id), ["2"])

        let city = builders.filtered(
            by: HubLocationFilter(scope: .city, city: "Austin, TX"),
            myLocation: nil,
            myLatitude: nil,
            myLongitude: nil
        )
        XCTAssertEqual(city.map(\.id), ["1"])

        let options = HubPlaceOptions.from(builders: builders)
        XCTAssertTrue(options.countries.contains("United States"))
        XCTAssertTrue(options.countries.contains("Germany"))
        XCTAssertEqual(options.cities.map(\.label).sorted(), ["Austin, TX", "Berlin, Germany"])
    }
}
