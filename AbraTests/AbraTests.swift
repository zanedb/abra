//
//  AbraTests.swift
//  AbraTests
//

@testable import Abra
import AVFAudio
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
    func testApproximateSongKeepsArtworkAndShowsAreaOnlyWhileSelected() throws {
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
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 2)
        XCTAssertTrue(mapView.overlays.isEmpty)

        let normalAnnotation = try XCTUnwrap(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.first { $0.shazamStream == stream })
        sheet.show(stream)
        let annotation = try XCTUnwrap(coordinator.lastSelectedAnnotation as? ShazamAnnotation)
        XCTAssertFalse(annotation === normalAnnotation)
        mapView.register(ShazamAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(ShazamAnnotation.self))
        let selectedView = try XCTUnwrap(coordinator.mapView(mapView, viewFor: annotation))
        XCTAssertNil(selectedView.clusteringIdentifier)
        XCTAssertEqual(selectedView.displayPriority, .required)
        XCTAssertEqual(selectedView.selectedZPriority, .max)
        coordinator.mapView(mapView, didDeselect: normalAnnotation)
        XCTAssertEqual(sheet.now, .stream(stream), "The normal pin's delayed callback must not dismiss the selected duplicate")
        XCTAssertEqual(annotation.artworkURL, stream.artworkURL)
        XCTAssertEqual(mapView.overlays.compactMap { $0 as? MKCircle }.first?.radius, 150)
        coordinator.syncAnnotations(shazams: [stream, other], spots: [])
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 3)
        XCTAssertTrue(mapView.annotations.contains { $0 === annotation })
        // A delayed callback for an annotation that is still selected is stale.
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .stream(stream))

        mapView.deselectAnnotation(annotation, animated: false)
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .none)
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 2)
        XCTAssertTrue(mapView.overlays.isEmpty)

        sheet.show(stream)
        sheet.show(other)
        coordinator.mapView(mapView, didDeselect: annotation)
        XCTAssertEqual(sheet.now, .stream(other))
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 3)
        XCTAssertEqual(mapView.overlays.compactMap { $0 as? MKCircle }.first?.radius, 625)

        sheet.now = .none
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 2)
        XCTAssertTrue(mapView.overlays.isEmpty)

        stream.horizontalAccuracy = 20
        coordinator.syncAnnotations(shazams: [stream, other], spots: [])
        XCTAssertEqual(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.count, 2)
        let preciseAnnotation = try XCTUnwrap(mapView.annotations.compactMap { $0 as? ShazamAnnotation }.first { $0.shazamStream == stream })
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
    func testPreciseSongSelectionKeepsArtworkVisibleBesideASpotMarker() throws {
        let song = ShazamStream(title: "Precise song", latitude: 37.78, longitude: -122.4)
        song.horizontalAccuracy = 6
        let spot = Spot(name: "Nearby venue", latitude: song.latitude, longitude: song.longitude)
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(modelContext: container.mainContext, sheetProvider: sheet)
        let map = MKMapView()
        coordinator.mapView = map
        coordinator.setupSheetProviderObservation()
        map.register(ShazamAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(ShazamAnnotation.self))
        coordinator.syncAnnotations(shazams: [song], spots: [spot])
        let normal = try XCTUnwrap(map.annotations.compactMap { $0 as? ShazamAnnotation }.first)
        sheet.show(song)
        let selected = try XCTUnwrap(coordinator.lastSelectedAnnotation as? ShazamAnnotation)
        XCTAssertFalse(selected === normal)
        XCTAssertEqual(selected.artworkURL, song.artworkURL)
        let view = try XCTUnwrap(coordinator.mapView(map, viewFor: selected))
        XCTAssertEqual(view.displayPriority, .required)
        XCTAssertEqual(view.selectedZPriority, .max)
        XCTAssertNil(view.clusteringIdentifier)
        XCTAssertTrue(map.overlays.isEmpty)
        coordinator.syncAnnotations(shazams: [song], spots: [spot])
        XCTAssertTrue(coordinator.lastSelectedAnnotation === selected)
        coordinator.mapView(map, didDeselect: normal)
        XCTAssertEqual(sheet.now, .stream(song))
        sheet.now = .none
        XCTAssertEqual(map.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)
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
        let approximate = provider.locationForMatch(at: matchTime, activity: nil)
        XCTAssertEqual(approximate?.horizontalAccuracy, 500)
        provider.currentLocation = fix(age: 30, accuracy: 3_000)
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

    private final class LocationManagerSpy: CLLocationManager {
        var requestCount = 0
        var startCount = 0
        var stopCount = 0
        override var authorizationStatus: CLAuthorizationStatus { .authorizedWhenInUse }
        override var accuracyAuthorization: CLAccuracyAuthorization { .fullAccuracy }
        override func requestLocation() { requestCount += 1 }
        override func startUpdatingLocation() { startCount += 1 }
        override func stopUpdatingLocation() { stopCount += 1 }
    }

    @MainActor
    func testContinuousLocationRefreshUsesIndependentManagerWithoutEndingBackgroundSession() {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        let provider = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        provider.startBackgroundLocationUpdates()
        provider.requestLocation()
        XCTAssertEqual(primary.startCount, 1)
        XCTAssertEqual(primary.stopCount, 0)
        XCTAssertEqual(primary.requestCount, 0, "One-shot requests on the running manager are ignored by Core Location")
        XCTAssertEqual(refresh.requestCount, 1)
        provider.requestLocation()
        XCTAssertEqual(refresh.requestCount, 1, "Coalesce requests while a refresh is in flight")
        let fix = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4), altitude: 0,
                             horizontalAccuracy: 500, verticalAccuracy: -1, timestamp: .now)
        provider.locationManager(refresh, didUpdateLocations: [fix])
        XCTAssertEqual(provider.locationForMatch(at: .now, activity: nil)?.timestamp, fix.timestamp)
        XCTAssertEqual(provider.currentLocation?.horizontalAccuracy, 500)
        provider.requestLocation()
        XCTAssertEqual(refresh.requestCount, 2, "A completed request must permit the next refresh")
        XCTAssertEqual(primary.stopCount, 0)
        XCTAssertLessThan(provider.refreshInterval(activity: nil), 180)
        provider.stopBackgroundLocationUpdates()
        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertFalse(refresh.allowsBackgroundLocationUpdates)
    }

    @MainActor
    func testColdMatchRequestsLocationAndRecoversWhenFirstFixArrives() async throws {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        let provider = ShazamProvider()
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        provider.configure(modelContext: context, location: location, motion: MotionProvider(), sheet: SheetProvider())
        let song = ShazamStream(title: "Cold start", latitude: 0, longitude: 0)
        context.insert(song)
        try context.save()
        provider.trackLocationRecovery(for: song, matchedAt: .now)
        XCTAssertEqual(primary.requestCount, 1)
        let fix = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4), altitude: 0,
                             horizontalAccuracy: 500, verticalAccuracy: -1, timestamp: .now)
        location.locationManager(primary, didUpdateLocations: [fix])
        // Delivery is main-actor isolated; geocoding can complete separately.
        await Task.yield()
        provider.resolvePendingMatchLocations()
        location.acceptPlacemark(MKPlacemark(coordinate: fix.coordinate,
            addressDictionary: ["City": "San Francisco"]), for: fix)
        XCTAssertEqual(song.latitude, fix.coordinate.latitude)
        XCTAssertEqual(song.city, "San Francisco")
        XCTAssertEqual(song.horizontalAccuracy, 500)
        XCTAssertNotNil(song.approximateLocationRadius)
        XCTAssertNil(song.spot)
    }

    @MainActor
    func testDelayedColdStartFixRecoversAsAnAreaRatherThanAPreciseVenue() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let location = LocationProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: MotionProvider(), sheet: SheetProvider())
        let matchedAt = Date()
        let song = ShazamStream(title: "Waiting for GPS", latitude: 0, longitude: 0)
        song.timestamp = matchedAt
        let nearbySpot = Spot(name: "Nearby venue", latitude: 37.78, longitude: -122.4)
        context.insert(song)
        context.insert(nearbySpot)
        try context.save()
        provider.trackLocationRecovery(for: song, matchedAt: matchedAt)
        let fix = CLLocation(coordinate: nearbySpot.coordinate, altitude: 0,
                             horizontalAccuracy: 8, verticalAccuracy: -1,
                             timestamp: matchedAt.addingTimeInterval(20))
        location.currentLocation = fix
        provider.resolvePendingMatchLocations(at: matchedAt.addingTimeInterval(21))
        location.acceptPlacemark(MKPlacemark(coordinate: fix.coordinate,
            addressDictionary: ["City": "San Francisco"]), for: fix)
        XCTAssertEqual(song.latitude, fix.coordinate.latitude)
        XCTAssertEqual(song.city, "San Francisco")
        XCTAssertEqual(song.locationObservedAt, fix.timestamp)
        XCTAssertEqual(song.horizontalAccuracy, 8, "Preserve the actual reported GPS accuracy")
        XCTAssertEqual(song.approximateLocationRadius, 408)
        XCTAssertNil(song.spot, "Later observation cannot prove the song was at that precise venue")
    }

    @MainActor
    func testStationaryPreciseFixRemainsPreciseAndAssignsNearbySpotAfterNinetySeconds() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let song = ShazamStream(title: "Stationary venue match", latitude: 37.78, longitude: -122.4)
        song.horizontalAccuracy = 6.2
        song.locationObservedAt = song.timestamp.addingTimeInterval(-91.6)
        song.motionActivity = "stationary"
        song.speed = -1
        let spot = Spot(name: "Current venue", latitude: song.latitude, longitude: song.longitude)
        context.insert(song)
        context.insert(spot)
        try context.save()
        XCTAssertNil(song.approximateLocationRadius)
        song.spotIt(context: context)
        XCTAssertEqual(song.spot?.persistentModelID, spot.persistentModelID)
        // A subsequently acquired fix is also precise if stationary evidence
        // covers the complete observation/recognition interval.
        song.locationObservedAt = song.timestamp.addingTimeInterval(20)
        XCTAssertNil(song.approximateLocationRadius)
        song.horizontalAccuracy = 500
        XCTAssertEqual(song.approximateLocationRadius, 500, "Stationary motion must not upgrade genuinely coarse GPS")
        song.horizontalAccuracy = 6.2
        song.motionActivity = "unknown"
        XCTAssertNotNil(song.approximateLocationRadius, "Unknown motion must retain time-based uncertainty")
    }

    func testHistoricalManualCorrectionDoesNotProjectDaysOfTravelIntoRadius() {
        let song = ShazamStream(title: "Historical correction", latitude: 37.78, longitude: -122.4)
        song.horizontalAccuracy = 8
        song.locationObservedAt = song.timestamp.addingTimeInterval(3 * 24 * 60 * 60)
        XCTAssertNil(song.approximateLocationRadius)
        song.horizontalAccuracy = 500
        XCTAssertEqual(song.approximateLocationRadius, 500)
        song.horizontalAccuracy = 8
        song.locationObservedAt = song.timestamp.addingTimeInterval(20)
        XCTAssertEqual(song.approximateLocationRadius, 408)
    }

    func testStationaryEvidenceMustCoverTheFixAndRecognitionInterval() {
        let match = Date()
        let fix = match.addingTimeInterval(-92)
        XCTAssertTrue(MotionProvider.stationaryCoversInterval(isStationary: true, confidence: .high,
            since: fix.addingTimeInterval(-60), observation: fix, match: match))
        XCTAssertFalse(MotionProvider.stationaryCoversInterval(isStationary: true, confidence: .high,
            since: match.addingTimeInterval(-5), observation: fix, match: match))
        XCTAssertFalse(MotionProvider.stationaryCoversInterval(isStationary: true, confidence: .low,
            since: fix.addingTimeInterval(-60), observation: fix, match: match))
        XCTAssertFalse(MotionProvider.stationaryCoversInterval(isStationary: false, confidence: .high,
            since: fix.addingTimeInterval(-60), observation: fix, match: match))
        XCTAssertFalse(MotionProvider.stationaryCoversInterval(isStationary: true, confidence: .high,
            since: match.addingTimeInterval(5), observation: match.addingTimeInterval(20), match: match))
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
    func testManualPreciseLocationJoinsNearbySpotButApproximateDoesNot() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let spot = Spot(name: "AMC Metreon", latitude: 37.7843, longitude: -122.4039)
        let song = ShazamStream(title: "Correct me", latitude: 37.7, longitude: -122.4)
        context.insert(spot)
        context.insert(song)
        try context.save()
        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        item.name = spot.name
        try song.saveLocationEdit { song, context in
            song.setLocationFromPicker(item, context: context)
        }
        XCTAssertEqual(song.spot?.persistentModelID, spot.persistentModelID)
        let reader = ModelContext(container)
        let stored = try XCTUnwrap(reader.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertEqual(stored.spot?.name, spot.name)
        let approximate = CLLocation(coordinate: spot.coordinate, altitude: 0,
            horizontalAccuracy: 5_000, verticalAccuracy: -1, timestamp: .now)
        try song.saveLocationEdit { song, context in
            song.setLocationFromPicker(approximate, context: context)
        }
        XCTAssertNil(song.spot)
        let precise = CLLocation(coordinate: spot.coordinate, altitude: 0,
            horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: .now)
        try song.saveLocationEdit { song, context in
            song.setLocationFromPicker(precise, context: context, allowSpot: false)
        }
        XCTAssertNil(song.spot, "Reduced permission must win even if reported accuracy looks precise")
        try song.saveLocationEdit { song, context in
            song.setLocationFromPicker(precise, context: context)
        }
        XCTAssertEqual(song.spot?.persistentModelID, spot.persistentModelID)
    }

    @MainActor
    func testNewSpotDoesNotCollectApproximateSongs() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let spot = Spot(name: "Venue", latitude: 37.78, longitude: -122.4)
        let precise = ShazamStream(title: "Precise", latitude: spot.latitude, longitude: spot.longitude)
        precise.horizontalAccuracy = 10
        let approximate = ShazamStream(title: "Approximate", latitude: spot.latitude, longitude: spot.longitude)
        approximate.horizontalAccuracy = 5_000
        context.insert(spot)
        context.insert(precise)
        context.insert(approximate)
        try context.save()
        approximate.spotIt(context: context)
        XCTAssertNil(approximate.spot)
        spot.appendNearbyShazamStreams(context)
        XCTAssertEqual(precise.spot?.persistentModelID, spot.persistentModelID)
        XCTAssertNil(approximate.spot)
    }

    @MainActor
    func testRadiusAnimationReversalCompletesAndDoesNotRetainRenderer() async {
        var renderer: ApproximateAreaRenderer? = ApproximateAreaRenderer(
            overlay: MKCircle(center: .init(latitude: 37.78, longitude: -122.4), radius: 5_000))
        weak let weakRenderer = renderer
        let opened = expectation(description: "Radius opens")
        renderer?.animate(to: 1) { opened.fulfill() }
        await fulfillment(of: [opened], timeout: 1)
        renderer?.animate(to: 0)
        try? await Task.sleep(for: .milliseconds(70))
        // Reverse an in-flight close, as when quickly reselecting a song.
        let reopened = expectation(description: "Radius reopens")
        renderer?.animate(to: 1) { reopened.fulfill() }
        await fulfillment(of: [reopened], timeout: 1)
        let closed = expectation(description: "Radius closes")
        renderer?.animate(to: 0) { closed.fulfill() }
        await fulfillment(of: [closed], timeout: 1)
        renderer?.animate(to: 1)
        renderer = nil
        XCTAssertNil(weakRenderer, "An active display link must not retain its renderer")
    }

    @MainActor
    func testPlaybackTimelineSuppressesLongPlayAndAllowsQuickReplay() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: start,
                                      shazamID: "a", playbackPosition: 50)
        provider.recordSuccessfulMatch(title: "Stray", artist: "Other", at: start.addingTimeInterval(10),
                                      shazamID: "b", playbackPosition: 100)
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(20),
                                                  shazamID: "a", playbackPosition: 72))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Next", artist: "Other", at: start.addingTimeInterval(21),
                                                 shazamID: "c", playbackPosition: 0))
        // Keep the same play alive past the former six-minute suppression window.
        for elapsed in stride(from: 40.0, through: 600.0, by: 20) {
            XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(elapsed),
                                                      shazamID: "a", playbackPosition: 50 + elapsed))
        }
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(601),
                                                  shazamID: "a", playbackPosition: 2))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(604),
                                                 shazamID: "a", playbackPosition: 5))
        provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(604),
                                      shazamID: "a", playbackPosition: 5)
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(611),
                                                  shazamID: "a", playbackPosition: 12))
        // Even a long run of unrelated results must not expire a valid timeline.
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(1_211),
                                                  shazamID: "a", playbackPosition: 612))
    }

    @MainActor
    func testPlaybackTimelineToleratesTempoAndSeparatesRecordings() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        provider.recordSuccessfulMatch(title: "Same title", artist: "Artist", at: start,
                                      shazamID: "studio", playbackPosition: 100, playbackRate: 1.1)
        XCTAssertFalse(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(100),
                                                  shazamID: "studio", playbackPosition: 212, playbackRate: 1.1))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(101),
                                                 shazamID: "live", playbackPosition: 213))
        // Missing/non-finite offsets use bounded legacy suppression, never NaN arithmetic.
        XCTAssertFalse(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(102),
                                                  shazamID: "studio", playbackPosition: .nan))
        // A second advancing result confirms a replay without a fixed cooldown.
        XCTAssertFalse(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(110),
                                                  shazamID: "studio", playbackPosition: 0))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(113),
                                                 shazamID: "studio", playbackPosition: 3))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Same title", artist: "Artist", at: start.addingTimeInterval(500),
                                                 shazamID: "studio", playbackPosition: nil))
    }

    @MainActor
    func testSameRecordingOffsetJumpsDoNotCreateThreeMatchesInTenSeconds() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var savedCount = 0
        // The on-device duplicate rows have identical catalog IDs. Exercise both
        // forward section jumps and returns to the original section under that ID.
        for (elapsed, position) in [(0.0, 40.0), (3, 160), (6, 46), (9, 166)] {
            let date = start.addingTimeInterval(elapsed)
            if provider.shouldRecordMatch(title: "Song", artist: "Artist", at: date,
                                          shazamID: "same-recording", playbackPosition: position) {
                savedCount += 1
                provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: date,
                                               shazamID: "same-recording", playbackPosition: position)
            }
        }
        XCTAssertEqual(savedCount, 1)
    }

    @MainActor
    func testBackwardOutlierAndFrozenOffsetDoNotConfirmReplay() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: start,
                                      shazamID: "a", playbackPosition: 160)
        // One backward section match is followed by the original timeline.
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(3),
                                                  shazamID: "a", playbackPosition: 40))
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(6),
                                                  shazamID: "a", playbackPosition: 166))
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(9),
                                                  shazamID: "a", playbackPosition: 46))
        // Stalled predictions cannot count as independent advancing evidence.
        for elapsed in [12.0, 15, 18, 21] {
            XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist", at: start.addingTimeInterval(elapsed),
                                                      shazamID: "a", playbackPosition: 0))
        }
        XCTAssertTrue(provider.shouldRecordMatch(title: "Different song", artist: "Artist", at: start.addingTimeInterval(22),
                                                 shazamID: "b", playbackPosition: 0))
    }

    @MainActor
    func testInterveningFalseMatchDoesNotReadmitPlayingSong() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(provider.shouldRecordMatch(title: "Actual song", artist: "Artist", at: start))
        provider.recordSuccessfulMatch(title: "Actual song", artist: "Artist", at: start)
        XCTAssertTrue(provider.shouldRecordMatch(title: "Stray match", artist: "Other", at: start.addingTimeInterval(40)))
        provider.recordSuccessfulMatch(title: "Stray match", artist: "Other", at: start.addingTimeInterval(40))
        XCTAssertFalse(provider.shouldRecordMatch(title: "actual song", artist: "Artist", at: start.addingTimeInterval(120)))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Actual song", artist: "Artist", at: start.addingTimeInterval(361)))
    }

    @MainActor
    func testLateLocationCannotReplaceManualLocationOrTouchDeletedSong() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let stream = ShazamStream(title: "Needs location", latitude: 0, longitude: 0)
        context.insert(stream)
        try context.save()
        let location = LocationProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: MotionProvider(), sheet: SheetProvider())
        let matchedAt = Date()
        provider.trackLocationRecovery(for: stream, matchedAt: matchedAt)
        let chosen = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 37.7843, longitude: -122.4039)))
        chosen.name = "AMC Metreon"
        try stream.saveLocationEdit { song, _ in song.setLocationFromPicker(chosen) }
        location.currentLocation = CLLocation(latitude: 37.7, longitude: -122.5)
        provider.resolvePendingMatchLocations()
        XCTAssertEqual(stream.latitude, chosen.placemark.coordinate.latitude)
        XCTAssertEqual(stream.placemarkName, "AMC Metreon")

        let deleted = ShazamStream(title: "Deleted", latitude: 0, longitude: 0)
        context.insert(deleted)
        try context.save()
        provider.trackLocationRecovery(for: deleted, matchedAt: matchedAt)
        context.delete(deleted)
        provider.resolvePendingMatchLocations()
        try context.save()
        provider.resolvePendingMatchLocations()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShazamStream>()), 1)
    }

    @MainActor
    func testDelayedPlaceNameEnrichesOriginalFixAfterUserMoves() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let stream = ShazamStream(title: "Needs place name", latitude: 0, longitude: 0)
        context.insert(stream)
        try context.save()
        let location = LocationProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: MotionProvider(), sheet: SheetProvider())
        let fix = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4),
                             altitude: 0, horizontalAccuracy: 120, verticalAccuracy: -1, timestamp: .now)
        provider.trackLocationRecovery(for: stream, matchedAt: .now)
        location.currentLocation = fix
        provider.resolvePendingMatchLocations()
        XCTAssertEqual(stream.latitude, fix.coordinate.latitude)
        XCTAssertNil(stream.city)
        let placemark = MKPlacemark(coordinate: fix.coordinate, addressDictionary: ["City": "San Francisco"])
        location.currentLocation = CLLocation(latitude: 38.1, longitude: -122.7)
        location.acceptPlacemark(placemark, for: fix)
        XCTAssertEqual(stream.city, "San Francisco")
        XCTAssertEqual(stream.latitude, fix.coordinate.latitude)
        XCTAssertEqual(stream.locationObservedAt, fix.timestamp)
        XCTAssertNil(location.currentPlacemark)
    }

    @MainActor
    func testLatePlacemarkCannotRelabelManualCorrection() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let stream = ShazamStream(title: "Original fix", latitude: 37.78, longitude: -122.4)
        stream.locationObservedAt = .now
        context.insert(stream)
        try context.save()
        let location = LocationProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: MotionProvider(), sheet: SheetProvider())
        provider.trackLocationRecovery(for: stream, matchedAt: .now)
        let oldFix = stream.location
        let selected = MKMapItem(placemark: MKPlacemark(
            coordinate: .init(latitude: 37.8, longitude: -122.27), addressDictionary: ["City": "Oakland"]))
        selected.name = "Chosen venue"
        try stream.saveLocationEdit { song, _ in song.setLocationFromPicker(selected) }
        location.acceptPlacemark(MKPlacemark(coordinate: oldFix.coordinate,
            addressDictionary: ["City": "San Francisco"]), for: oldFix)
        XCTAssertEqual(stream.city, "Oakland")
        XCTAssertEqual(stream.placemarkName, "Chosen venue")
    }

    @MainActor
    func testFailedRecognitionSaveRetainsRowAndRetriesExactlyOnce() throws {
        enum SaveFailure: Error { case simulated }
        var shouldFail = true
        let provider = ShazamProvider(saveMatchContext: { context in
            if shouldFail { throw SaveFailure.simulated }
            try context.save()
        })
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let location = LocationProvider()
        provider.configure(modelContext: container.mainContext, location: location,
                           motion: MotionProvider(), sheet: SheetProvider())
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        let song = ShazamStream(title: "Don't lose me", artist: "Artist", latitude: 0, longitude: 0)
        song.shazamID = "retry-song"
        writer.insert(song)
        var savedCount = 0
        provider.queueRecognizedMatch(song, in: writer, at: .now, playbackPosition: 42) { saved in
            savedCount += 1
            XCTAssertTrue(saved.modelContext === container.mainContext)
        }
        XCTAssertEqual(provider.pendingMatchSaveCount, 1)
        XCTAssertEqual(savedCount, 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ShazamStream>()), 0)
        let fix = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4),
                             altitude: 0, horizontalAccuracy: 120, verticalAccuracy: -1, timestamp: .now)
        location.currentLocation = fix
        provider.resolvePendingMatchLocations()
        location.acceptPlacemark(MKPlacemark(coordinate: fix.coordinate,
            addressDictionary: ["City": "San Francisco"]), for: fix)
        shouldFail = false
        provider.retryPendingMatches()
        XCTAssertEqual(provider.pendingMatchSaveCount, 0)
        XCTAssertEqual(savedCount, 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ShazamStream>()), 1)
        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertEqual(saved.latitude, fix.coordinate.latitude)
        XCTAssertEqual(saved.city, "San Francisco")
        provider.retryPendingMatches()
        XCTAssertEqual(savedCount, 1)
        XCTAssertFalse(provider.shouldRecordMatch(title: song.title, artist: song.artist, at: .now,
                                                   shazamID: "retry-song", playbackPosition: 43))
    }

    @MainActor
    func testPickerFailedSaveLeavesOriginalLocationSpotAndUnsavedNote() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let schema = Schema([ShazamStream.self, Spot.self])
        do {
            let container = try ModelContainer(for: schema,
                configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let original = ShazamStream(title: "Original", latitude: 37.7, longitude: -122.4)
            let spot = Spot(name: "Original venue")
            container.mainContext.insert(original)
            container.mainContext.insert(spot)
            original.spot = spot
            try container.mainContext.save()
        }
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none))
        container.mainContext.autosaveEnabled = false
        let stream = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ShazamStream>()).first)
        stream.note = "Unrelated unsaved note"
        XCTAssertThrowsError(try stream.saveLocationEdit { song, _ in
            song.setLocationFromPicker(CLLocation(latitude: 38, longitude: -123))
        })
        XCTAssertEqual(stream.latitude, 37.7)
        XCTAssertEqual(stream.longitude, -122.4)
        XCTAssertEqual(stream.spot?.name, "Original venue")
        XCTAssertEqual(stream.note, "Unrelated unsaved note")
    }

    @MainActor
    func testCommittedLocationEditPreservesUnrelatedUnsavedNote() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let stream = ShazamStream(title: "Edit location", latitude: 37.7, longitude: -122.4)
        stream.note = "Saved note"
        context.insert(stream)
        try context.save()
        stream.note = "Unrelated unsaved edit"
        let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 38, longitude: -123)))
        item.name = "Chosen venue"
        try stream.saveLocationEdit { song, _ in song.setLocationFromPicker(item) }
        let reader = ModelContext(container)
        let saved = try XCTUnwrap(reader.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertEqual(saved.latitude, 38)
        XCTAssertEqual(saved.placemarkName, "Chosen venue")
        XCTAssertEqual(saved.locationObservedAt, stream.locationObservedAt)
        XCTAssertEqual(saved.note, "Saved note")
        XCTAssertEqual(stream.note, "Unrelated unsaved edit")
    }

    @MainActor
    private func configureInterruptionTest(_ provider: ShazamProvider) throws -> ModelContainer {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        provider.configure(modelContext: container.mainContext,
            location: LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy()),
            motion: MotionProvider(), sheet: SheetProvider())
        return container
    }

    @MainActor
    func testContinuousInterruptionResumesWithoutLosingSongHistory() async throws {
        var activations = 0
        var consumers = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return true },
            microphoneAuthorization: { true }, matchingTaskFactory: {
                consumers += 1
                return Task { try? await Task.sleep(for: .seconds(30)) }
            })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        provider.continuous = true
        await provider.beginMatching()
        let matchedAt = Date()
        provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: matchedAt,
            shazamID: "one", playbackPosition: 30)

        provider.pauseForAudioInterruption(reason: "Timer")
        provider.pauseForAudioInterruption(reason: "Duplicate timer event")
        XCTAssertTrue(provider.isListening)
        XCTAssertTrue(provider.isPausedForInterruption)
        XCTAssertEqual(provider.status, .paused)
        XCTAssertTrue(provider.activityState(takingTooLong: false).isPaused)
        XCTAssertEqual(consumers, 1)

        provider.resumeAfterAudioInterruption(shouldResume: true)
        provider.resumeAfterAudioInterruption(shouldResume: true)
        XCTAssertTrue(provider.isListening)
        XCTAssertTrue(provider.continuous)
        XCTAssertFalse(provider.isPausedForInterruption)
        XCTAssertEqual(provider.status, .matching)
        XCTAssertFalse(provider.activityState(takingTooLong: false).isPaused)
        XCTAssertEqual(activations, 2)
        XCTAssertEqual(consumers, 2)
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist",
            at: matchedAt.addingTimeInterval(10), shazamID: "one", playbackPosition: 40))
    }

    @MainActor
    func testInterruptedSessionWaitsForPermissionAndSuccessfulAudioActivation() async throws {
        var canActivate = true
        var activations = 0
        var consumers = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return canActivate },
            microphoneAuthorization: { true }, matchingTaskFactory: {
                consumers += 1
                return Task { try? await Task.sleep(for: .seconds(30)) }
            })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        provider.continuous = true
        await provider.beginMatching()
        provider.pauseForAudioInterruption(reason: "Timer")
        provider.resumeAfterAudioInterruption(shouldResume: false)
        XCTAssertTrue(provider.isPausedForInterruption)
        XCTAssertEqual(activations, 1)
        canActivate = false
        provider.resumeAfterAudioInterruption(shouldResume: true)
        XCTAssertTrue(provider.isPausedForInterruption)
        XCTAssertEqual(consumers, 1)
        canActivate = true
        provider.resumeAfterAudioInterruption(shouldResume: true)
        XCTAssertFalse(provider.isPausedForInterruption)
        XCTAssertEqual(consumers, 2)
    }

    @MainActor
    func testStopOrDisablingContinuousWhilePausedPreventsLateResumption() async throws {
        var activations = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return true },
            microphoneAuthorization: { true }, matchingTaskFactory: { Task {} })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        for disableContinuous in [false, true] {
            provider.continuous = true
            await provider.beginMatching()
            provider.pauseForAudioInterruption(reason: "Timer")
            if disableContinuous { provider.continuous = false }
            else { provider.stopMatching() }
            let activationCount = activations
            provider.resumeAfterAudioInterruption(shouldResume: true)
            provider.recoverInterruptedListeningOnForeground()
            XCTAssertFalse(provider.isListening)
            XCTAssertFalse(provider.continuous)
            XCTAssertFalse(provider.isPausedForInterruption)
            XCTAssertEqual(provider.status, .idle)
            XCTAssertEqual(activations, activationCount)
        }
    }

    @MainActor
    func testForegroundRecoversMissingResumptionEventButHonoursSystemDenial() async throws {
        var canActivate = true
        var activations = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return canActivate },
            microphoneAuthorization: { true }, matchingTaskFactory: { Task {} })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        provider.continuous = true
        await provider.beginMatching()
        provider.pauseForAudioInterruption(reason: "Timer without an end event")
        canActivate = false
        provider.recoverInterruptedListeningOnForeground()
        XCTAssertTrue(provider.isPausedForInterruption)
        canActivate = true
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        // The notification bridge deliberately hops to the main actor.
        for _ in 0..<50 {
            if !provider.isPausedForInterruption { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(provider.status, .matching)
        XCTAssertFalse(provider.isPausedForInterruption)
        XCTAssertEqual(activations, 3)

        provider.pauseForAudioInterruption(reason: "New interruption")
        provider.resumeAfterAudioInterruption(shouldResume: false)
        provider.recoverInterruptedListeningOnForeground()
        XCTAssertTrue(provider.isPausedForInterruption)
        XCTAssertEqual(activations, 3, "Foreground must not override an explicit system denial")
        provider.resumeAfterAudioInterruption(shouldResume: true)
        XCTAssertFalse(provider.isPausedForInterruption)
    }

    @MainActor
    func testSingleMatchInterruptionStillStops() async throws {
        var activations = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return true },
            microphoneAuthorization: { true }, matchingTaskFactory: { Task {} })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        await provider.beginMatching()
        provider.pauseForAudioInterruption(reason: "Timer")
        provider.resumeAfterAudioInterruption(shouldResume: true)
        XCTAssertFalse(provider.isListening)
        XCTAssertFalse(provider.isPausedForInterruption)
        XCTAssertEqual(provider.status, .error(.audioSessionFailed))
        XCTAssertEqual(activations, 1)
    }

    @MainActor
    func testLegacyInterruptionEndResumesWhenNewRecommendationIsMissing() async throws {
        var activations = 0
        let provider = ShazamProvider(audioActivation: { activations += 1; return true },
            microphoneAuthorization: { true }, matchingTaskFactory: { Task {} })
        let container = try configureInterruptionTest(provider)
        defer { provider.stopMatching(); _ = container }
        provider.continuous = true
        await provider.beginMatching()
        provider.pauseForAudioInterruption(reason: "Timer")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ])
        for _ in 0..<50 {
            if !provider.isPausedForInterruption { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(provider.isListening)
        XCTAssertFalse(provider.isPausedForInterruption)
        XCTAssertEqual(activations, 2)
    }

    func testOldLiveActivityPayloadDecodesWithDefaults() throws {
        let data = Data(#"{"takingTooLong":true}"#.utf8)
        let state = try JSONDecoder().decode(WidgetAttributes.ContentState.self, from: data)
        XCTAssertTrue(state.takingTooLong)
        XCTAssertFalse(state.continuous)
        XCTAssertFalse(state.isPaused)
        XCTAssertEqual(state.matchCount, 0)
        XCTAssertNil(state.locationName)
        let current = WidgetAttributes.ContentState(takingTooLong: false, continuous: true,
            matchCount: 7, isPaused: true, locationName: "Mission", matchedTitle: "Song", matchedArtist: "Artist")
        XCTAssertEqual(try JSONDecoder().decode(WidgetAttributes.ContentState.self,
            from: JSONEncoder().encode(current)), current)
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
