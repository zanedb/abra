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
}
