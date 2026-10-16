//
//  AbraTests.swift
//  AbraTests
//

@testable import Abra
import MapKit
import SwiftData
import XCTest

final class AbraTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAnnotationSnapshotsTrackModelChanges() {
        let oldArtworkURL = URL(string: "https://example.com/old.png")!
        let newArtworkURL = URL(string: "https://example.com/new.png")!
        let stream = ShazamStream(
            title: "Old title",
            artworkURL: oldArtworkURL,
            latitude: 1,
            longitude: 2
        )
        let shazamAnnotation = ShazamAnnotation(shazamStream: stream)

        stream.title = "New title"
        stream.artworkURL = newArtworkURL
        stream.latitude = 3
        stream.longitude = 4

        let streamChanges = shazamAnnotation.update(from: stream)
        XCTAssertTrue(streamChanges.changed)
        XCTAssertTrue(streamChanges.artworkChanged)
        XCTAssertEqual(shazamAnnotation.title, "New title")
        XCTAssertEqual(shazamAnnotation.artworkURL, newArtworkURL)
        XCTAssertEqual(shazamAnnotation.coordinate.latitude, 3)
        XCTAssertEqual(shazamAnnotation.coordinate.longitude, 4)

        let spot = Spot(
            name: "Old spot",
            symbol: "house",
            color: .systemBlue,
            latitude: 5,
            longitude: 6
        )
        let spotAnnotation = SpotAnnotation(spot: spot)

        spot.name = "New spot"
        spot.symbol = "music.note"
        spot.color = .systemOrange
        spot.latitude = 7
        spot.longitude = 8

        let spotChanges = spotAnnotation.update(from: spot)
        XCTAssertTrue(spotChanges.changed)
        XCTAssertTrue(spotChanges.appearanceChanged)
        XCTAssertEqual(spotAnnotation.title, "New spot")
        XCTAssertEqual(spotAnnotation.symbol, "music.note")
        XCTAssertTrue(spotAnnotation.color.isEqual(spot.color))
        XCTAssertEqual(spotAnnotation.coordinate.latitude, 7)
        XCTAssertEqual(spotAnnotation.coordinate.longitude, 8)
    }

    @MainActor
    func testApproximateSongAppearsOnlyWhileOpenWithStableArtworkAnnotation() throws {
        let stream = ShazamStream(title: "Approximate", latitude: 37.7, longitude: -122.4)
        stream.horizontalAccuracy = 120
        stream.locationObservedAt = stream.timestamp
        let other = ShazamStream(title: "Another approximate song", latitude: 37.8, longitude: -122.5)
        other.horizontalAccuracy = 500
        other.locationObservedAt = other.timestamp
        let container = try ModelContainer(
            for: Schema([ShazamStream.self, Spot.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext, sheetProvider: sheet
        )
        let mapView = MKMapView()
        coordinator.mapView = mapView
        coordinator.setupSheetProviderObservation()
        coordinator.syncAnnotations(shazams: [stream, other], spots: [])
        XCTAssertTrue(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
        XCTAssertTrue(mapView.overlays.isEmpty)

        sheet.show(stream)
        let annotation = try XCTUnwrap(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.first)
        XCTAssertEqual(annotation.artworkURL, stream.artworkURL)
        XCTAssertEqual(mapView.overlays.compactMap { $0 as? MKCircle }.first?.radius, 150)
        coordinator.syncAnnotations(shazams: [stream, other], spots: [])
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)
        XCTAssertTrue(mapView.annotations.contains { $0 === annotation })
        // A delayed callback for an annotation that is still selected is stale.
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .stream(stream))

        mapView.deselectAnnotation(annotation, animated: false)
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .none)
        XCTAssertTrue(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
        XCTAssertTrue(mapView.overlays.isEmpty)

        sheet.show(stream)
        sheet.show(other)
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .stream(other))
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)
        XCTAssertEqual(mapView.overlays.compactMap { $0 as? MKCircle }.first?.radius, 625)

        sheet.now = .none
        XCTAssertTrue(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
        XCTAssertTrue(mapView.overlays.isEmpty)

        stream.horizontalAccuracy = 20
        coordinator.syncAnnotations(shazams: [stream, other], spots: [])
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)
        let preciseAnnotation = try XCTUnwrap(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.first)
        sheet.show(other)
        let approximateAnnotation = try XCTUnwrap(mapView.annotations.compactMap { $0 as? ShazamAnnotation }
            .first { $0.shazamStream == other })
        mapView.selectAnnotation(preciseAnnotation, animated: false)
        coordinator.mapView(mapView, didDeselect: approximateAnnotation)
        XCTAssertTrue(mapView.selectedAnnotations.contains { $0 === preciseAnnotation })
        coordinator.mapView(mapView, didSelect: preciseAnnotation)
        XCTAssertEqual(sheet.now, .stream(stream))
        sheet.show(stream)
        XCTAssertTrue(mapView.overlays.isEmpty)
    }

    @MainActor
    func testCoordinatorReconcilesAddsUpdatesAndRemovals() throws {
        let stream = ShazamStream(title: "Stream", latitude: 1, longitude: 2)
        let spot = Spot(name: "Spot", latitude: 3, longitude: 4)
        let schema = Schema([ShazamStream.self, Spot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext,
            sheetProvider: SheetProvider()
        )
        let mapView = MKMapView()
        coordinator.mapView = mapView

        coordinator.syncAnnotations(shazams: [stream], spots: [spot])

        let shazamAnnotation = try XCTUnwrap(
            mapView.annotations.compactMap { $0 as? ShazamAnnotation }.first
        )
        let spotAnnotation = try XCTUnwrap(
            mapView.annotations.compactMap { $0 as? SpotAnnotation }.first
        )

        stream.title = "Updated stream"
        stream.latitude = 5
        spot.name = "Updated spot"
        spot.symbol = "music.note"

        coordinator.syncAnnotations(shazams: [stream], spots: [spot])

        XCTAssertTrue(
            mapView.annotations.contains { $0 === shazamAnnotation }
        )
        XCTAssertTrue(mapView.annotations.contains { $0 === spotAnnotation })
        XCTAssertEqual(shazamAnnotation.title, "Updated stream")
        XCTAssertEqual(shazamAnnotation.coordinate.latitude, 5)
        XCTAssertEqual(spotAnnotation.title, "Updated spot")
        XCTAssertEqual(spotAnnotation.symbol, "music.note")

        coordinator.syncAnnotations(shazams: [], spots: [])
        XCTAssertFalse(
            mapView.annotations.contains { $0 is ShazamAnnotation }
        )
        XCTAssertFalse(mapView.annotations.contains { $0 is SpotAnnotation })
    }

    func testSpotMomentGroupingUsesDayAndLocation() {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let inputs = [
            MomentSearchInput(
                timestamp: day,
                latitude: 37.7749,
                longitude: -122.4194
            ),
            MomentSearchInput(
                timestamp: day.addingTimeInterval(60),
                latitude: 37.7755,
                longitude: -122.4194
            ),
            MomentSearchInput(
                timestamp: day.addingTimeInterval(120),
                latitude: 37.7949,
                longitude: -122.4194
            ),
            MomentSearchInput(
                timestamp: nextDay,
                latitude: 37.7749,
                longitude: -122.4194
            ),
        ]

        let clusters = SpotMomentGrouper.clusters(
            for: inputs,
            calendar: calendar
        )

        XCTAssertEqual(clusters, [[0, 1], [2], [3]])
    }

    func testSpotMomentGroupingDeduplicatesAssetsAcrossSongsAndMoments() {
        let identifiers = SpotMomentGrouper.uniqueAssetIdentifiers(
            for: [[0, 1], [2]],
            identifiersByInput: [
                ["photo-a", "photo-b"],
                ["photo-b", "photo-c"],
                ["photo-c", "photo-d"],
            ]
        )

        XCTAssertEqual(
            identifiers,
            [["photo-a", "photo-b", "photo-c"], ["photo-d"]]
        )
    }

    @MainActor
    func testUnnamedSpotUsesNeighborhoodAsItsPlace() {
        let stream = ShazamStream(title: "Stream")
        stream.subLocality = "Mission"
        stream.city = "San Francisco"
        let spot = Spot(name: "", shazamStreams: [stream])
        stream.spot = spot

        XCTAssertNil(stream.spotName)
        XCTAssertEqual(stream.place, "Mission")

        spot.name = "  1015  "
        XCTAssertEqual(stream.spotName, "1015")
        XCTAssertEqual(stream.place, "1015")
    }

    @MainActor
    func testSheetPresentationBindingOnlyClearsOnDismissal() {
        let provider = SheetProvider()
        let spot = Spot(name: "Draft")
        provider.show(spot)

        provider.isPresentedBinding.wrappedValue = true
        XCTAssertEqual(provider.now, .spot(spot))

        provider.isPresentedBinding.wrappedValue = false
        XCTAssertEqual(provider.now, .none)
    }

    func testMatchLocationRejectsOldAndInaccurateFixes() {
        let provider = LocationProvider()
        let matchTime = Date()

        func fix(age: TimeInterval, accuracy: CLLocationAccuracy) -> CLLocation {
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: 10,
                timestamp: matchTime.addingTimeInterval(-age)
            )
        }

        provider.currentLocation = fix(age: 30, accuracy: 50)
        XCTAssertNotNil(provider.locationForMatch(at: matchTime, activity: nil))

        provider.currentLocation = fix(age: 400, accuracy: 50)
        XCTAssertNil(provider.locationForMatch(at: matchTime, activity: nil))

        provider.currentLocation = fix(age: 30, accuracy: 500)
        XCTAssertNil(provider.locationForMatch(at: matchTime, activity: nil))

        XCTAssertTrue(provider.acceptsMatchLocation(
            fix(age: 250, accuracy: 12_000), at: matchTime,
            activity: nil, reducedAccuracy: true
        ))
        XCTAssertFalse(provider.acceptsMatchLocation(
            fix(age: 400, accuracy: 12_000), at: matchTime,
            activity: nil, reducedAccuracy: true
        ))
    }

    @MainActor
    func testPickerCurrentLocationDoesNotRequirePlacemark() async throws {
        let provider = LocationProvider()
        provider.authorizationStatus = .authorizedWhenInUse
        let fix = CLLocation(
            coordinate: .init(latitude: 37.78, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 8_000,
            verticalAccuracy: -1, timestamp: .now
        )
        provider.currentLocation = fix
        provider.currentPlacemark = nil
        let selected = try await provider.locationForPicker()
        XCTAssertEqual(selected.coordinate.latitude, fix.coordinate.latitude)
        XCTAssertEqual(selected.horizontalAccuracy, 8_000)
    }

    @MainActor
    func testPickerSelectionPreservesChosenVenueAndReplacesOldSpot() {
        let stream = ShazamStream(title: "Song")
        stream.spot = Spot(name: "Solamat")
        let item = MKMapItem(placemark: MKPlacemark(
            coordinate: .init(latitude: 37.7843, longitude: -122.4039)
        ))
        item.name = "AMC Metreon"
        stream.setLocationFromPicker(item)
        XCTAssertNil(stream.spot)
        XCTAssertEqual(stream.placemarkName, "AMC Metreon")
        XCTAssertEqual(stream.latitude, item.placemark.coordinate.latitude)
        XCTAssertEqual(stream.longitude, item.placemark.coordinate.longitude)
        XCTAssertNil(stream.approximateLocationRadius)

        stream.spot = Spot(name: "Previous venue")
        let approximate = CLLocation(
            coordinate: .init(latitude: 37.78, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 8_000,
            verticalAccuracy: -1, timestamp: .now
        )
        stream.setLocationFromPicker(approximate)
        XCTAssertNil(stream.spot)
        XCTAssertEqual(stream.approximateLocationRadius, 8_000)
    }

    @MainActor
    func testInterveningFalseMatchDoesNotReadmitPlayingSong() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(provider.shouldRecordMatch(title: "Actual song", artist: "Artist", at: start))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Stray match", artist: "Other", at: start.addingTimeInterval(40)))
        XCTAssertFalse(provider.shouldRecordMatch(title: "actual song", artist: "Artist", at: start.addingTimeInterval(120)))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Actual song", artist: "Artist", at: start.addingTimeInterval(361)))
    }

    @MainActor
    func testNotificationMatchIDFetchFindsSavedSong() throws {
        let container = try ModelContainer(
            for: Schema([ShazamStream.self, Spot.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let song = ShazamStream(title: "Matched song")
        let id = UUID()
        song.matchID = id
        container.mainContext.insert(song)
        try container.mainContext.save()

        let descriptor = FetchDescriptor<ShazamStream>(
            predicate: #Predicate { $0.matchID == id }
        )
        XCTAssertEqual(try container.mainContext.fetch(descriptor).first?.title, "Matched song")
    }

    @MainActor
    func testSearchResultsAreRevealedImmediately() {
        let provider = SheetProvider()
        var revealCount = 0
        provider.revealSearchResults = { revealCount += 1 }

        provider.showSearchResults(for: "bassvictim")

        XCTAssertEqual(provider.searchText, "bassvictim")
        XCTAssertEqual(revealCount, 1)
    }
}
