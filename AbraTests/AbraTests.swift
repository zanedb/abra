//
//  AbraTests.swift
//  AbraTests
//

@testable import Abra
import CoreMotion
import Kingfisher
import MapKit
import MusicKit
import ShazamKit
import SwiftData
import SwiftUI
import UIKit
import XCTest

final class AbraTests: XCTestCase {

    private func versionSong(id: String = "222000", withOptionalMetadata: Bool = true) throws -> Song {
        var attributes: [String: Any] = [
            "name": "Song (Remastered)", "artistName": "Updated Artist",
            "albumName": "New Album", "genreNames": ["Alternative"],
            "releaseDate": "2024-01-05", "durationInMillis": 180000,
            "url": "https://music.apple.com/us/song/\(id)",
            "playParams": ["id": id, "kind": "song"]
        ]
        if withOptionalMetadata {
            attributes["artwork"] = ["url": "https://example.com/new/{w}x{h}.jpg", "width": 1200, "height": 1200]
            attributes["contentRating"] = "explicit"
            attributes["isrc"] = "USNEW2400001"
        }
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "type": "songs", "attributes": attributes])
        return try JSONDecoder().decode(Song.self, from: data)
    }

    @MainActor
    func testRelinkCommitsAllVersionMetadataAndPublishesItImmediately() async throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let stream = ShazamStream(title: "Old Song", artist: "Original Artist", appleMusicID: "111000")
        stream.subtitle = "Old subtitle"
        stream.videoURL = URL(string: "https://example.com/old-video")
        stream.isrc = "OLDISRC"
        stream.matchID = UUID()
        stream.shazamID = "original-shazam"
        stream.shazamLibraryID = UUID()
        stream.creationDate = Date(timeIntervalSince1970: 1000)
        stream.webURL = URL(string: "https://www.shazam.com/track/original")
        stream.note = "Saved note"
        let spot = Spot(name: "Original venue")
        context.insert(spot)
        context.insert(stream)
        stream.spot = spot
        try context.save()
        let originalID = stream.persistentModelID
        let originalMatchID = stream.matchID
        let originalShazamLibraryID = stream.shazamLibraryID
        let originalDate = stream.timestamp
        let originalCoordinate = stream.coordinate
        stream.note = "Unrelated unsaved note"

        var lookupCount = 0
        let music = MusicProvider(catalogLookup: { _ in lookupCount += 1; return [] })
        music.authorizationStatus = .authorized
        _ = try await music.fetchTrackInfo("111000")
        _ = try await music.fetchTrackInfo("222000")
        XCTAssertTrue(music.isSongUnavailable("222000"))
        let song = try versionSong()

        try music.relink(stream, to: song)

        XCTAssertEqual(stream.persistentModelID, originalID)
        XCTAssertEqual(stream.appleMusicID, song.id.rawValue)
        XCTAssertEqual(stream.appleMusicURL, song.url)
        XCTAssertEqual(stream.title, song.title)
        XCTAssertEqual(stream.artist, song.artistName)
        XCTAssertEqual(stream.artworkURL, song.artwork?.url(width: 600, height: 600))
        XCTAssertEqual(stream.isExplicit, song.contentRating == .explicit)
        XCTAssertEqual(stream.isrc, song.isrc)
        XCTAssertNil(stream.subtitle)
        XCTAssertNil(stream.videoURL)
        XCTAssertFalse(music.isSongUnavailable(stream.appleMusicID), "Share and music actions must become available before dismissal")
        XCTAssertTrue(music.isSongUnavailable("111000"), "Other listens of the removed version remain unavailable")
        XCTAssertEqual(music.cachedTrackInfo(stream.appleMusicID)?.albumTitle, "New Album")
        XCTAssertEqual(music.cachedTrackInfo(stream.appleMusicID)?.genreNames, ["Alternative"])
        XCTAssertEqual(music.cachedTrackInfo(stream.appleMusicID)?.releaseDate, song.releaseDate)
        let metadata = try await music.fetchTrackInfo("222000")
        XCTAssertEqual(metadata?.id, song.id)
        XCTAssertEqual(lookupCount, 2, "The new header must not wait for another network request")
        XCTAssertEqual(stream.note, "Unrelated unsaved note")
        XCTAssertEqual(stream.matchID, originalMatchID)
        XCTAssertEqual(stream.shazamLibraryID, originalShazamLibraryID)
        XCTAssertEqual(stream.shazamID, "original-shazam")
        XCTAssertEqual(stream.creationDate, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(stream.timestamp, originalDate)
        XCTAssertEqual(stream.coordinate.latitude, originalCoordinate.latitude)
        XCTAssertEqual(stream.coordinate.longitude, originalCoordinate.longitude)
        XCTAssertEqual(stream.spot, spot)

        let reopenedContext = ModelContext(container)
        let saved = try XCTUnwrap(reopenedContext.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertEqual(saved.appleMusicID, "222000")
        XCTAssertEqual(saved.title, song.title)
        XCTAssertEqual(saved.artist, song.artistName)
        XCTAssertEqual(saved.artworkURL, stream.artworkURL)
        XCTAssertEqual(saved.isrc, song.isrc)
        XCTAssertTrue(saved.isExplicit)
        XCTAssertNil(saved.subtitle)
        XCTAssertNil(saved.videoURL)
        XCTAssertEqual(saved.note, "Saved note", "Relinking must not commit unrelated edits")
    }

    @MainActor
    func testRelinkClearsOldOptionalVersionMetadata() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let stream = ShazamStream(title: "Old", isExplicit: true, appleMusicID: "111000")
        stream.isrc = "OLDISRC"
        stream.subtitle = "Old subtitle"
        stream.videoURL = URL(string: "https://example.com/old-video")
        context.insert(stream)
        try context.save()
        let music = MusicProvider()
        let song = try versionSong(withOptionalMetadata: false)

        try music.relink(stream, to: song)

        XCTAssertNil(stream.isrc)
        XCTAssertNil(stream.subtitle)
        XCTAssertNil(stream.videoURL)
        XCTAssertFalse(stream.isExplicit)
        XCTAssertEqual(stream.artworkURL.absoluteString, "https://zane.link/abra-unavailable")
        XCTAssertEqual(music.cachedTrackInfo(stream.appleMusicID)?.id, song.id)
    }

    @MainActor
    func testFailedRelinkLeavesModelAndMetadataCacheUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let schema = Schema([ShazamStream.self, Spot.self])
        do {
            let container = try ModelContainer(for: schema,
                configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let stream = ShazamStream(title: "Original", artist: "Original Artist", appleMusicID: "111000")
            container.mainContext.insert(stream)
            try container.mainContext.save()
        }
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none))
        container.mainContext.autosaveEnabled = false
        let stream = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ShazamStream>()).first)
        let originalArtwork = stream.artworkURL
        stream.note = "Unrelated unsaved note"
        let music = MusicProvider()
        let song = try versionSong()

        XCTAssertThrowsError(try music.relink(stream, to: song))

        XCTAssertEqual(stream.appleMusicID, "111000")
        XCTAssertEqual(stream.title, "Original")
        XCTAssertEqual(stream.artist, "Original Artist")
        XCTAssertEqual(stream.artworkURL, originalArtwork)
        XCTAssertEqual(stream.note, "Unrelated unsaved note")
        XCTAssertNil(music.cachedTrackInfo(song.id.rawValue))
    }

    @MainActor
    func testRelinkRejectsDetachedSong() throws {
        let stream = ShazamStream(title: "Original", appleMusicID: "111000")
        let music = MusicProvider()
        XCTAssertThrowsError(try music.relink(stream, to: versionSong()))
        XCTAssertEqual(stream.appleMusicID, "111000")
        XCTAssertEqual(stream.title, "Original")
        XCTAssertNil(music.cachedTrackInfo("222000"))
    }

    @MainActor
    func testSongPreviewCommitOpensSongAfterMenuDismissalWithoutPlaying() {
        let sheet = SheetProvider()
        let stream = ShazamStream.preview
        sheet.show(Spot.preview)
        var playbackTriggered = false
        let contextMenu = SongRowContextMenu(
            appleMusicURL: nil,
            onTap: { playbackTriggered = true },
            onViewSong: { sheet.show(stream) },
            preview: Text(stream.title)
        )
        let coordinator = contextMenu.makeCoordinator()
        let interaction = UIContextMenuInteraction(delegate: coordinator)
        let animator = PreviewCommitAnimator()

        coordinator.contextMenuInteraction(
            interaction,
            willPerformPreviewActionForMenuWith: UIContextMenuConfiguration(),
            animator: animator
        )

        XCTAssertNotNil(sheet.spot, "Keep the spot visible until the menu closes")
        XCTAssertNil(sheet.stream)
        XCTAssertEqual(animator.preferredCommitStyle, .dismiss)
        XCTAssertEqual(animator.completions.count, 1)
        animator.completions.forEach { $0() }
        XCTAssertEqual(sheet.stream, stream)
        XCTAssertNil(sheet.spot)
        XCTAssertFalse(playbackTriggered)
    }

    @MainActor
    func testViewSongMenuActionWorksBeforeDuringAndAfterDismissal() {
        for actionStage in 0..<3 {
            var openedSongs = 0
            let contextMenu = SongRowContextMenu(
                appleMusicURL: nil,
                onTap: {},
                onViewSong: { openedSongs += 1 },
                preview: Text("Song")
            )
            let coordinator = contextMenu.makeCoordinator()
            let interaction = UIContextMenuInteraction(delegate: coordinator)
            let animator = PreviewCommitAnimator()
            if actionStage == 0 { coordinator.showSongAfterMenuDismissal() }
            coordinator.contextMenuInteraction(
                interaction, willEndFor: UIContextMenuConfiguration(), animator: animator
            )
            if actionStage == 1 { coordinator.showSongAfterMenuDismissal() }
            XCTAssertEqual(openedSongs, 0, "Wait for menu dismissal before revealing SongView")
            animator.completions.forEach { $0() }
            if actionStage == 2 { coordinator.showSongAfterMenuDismissal() }
            XCTAssertEqual(openedSongs, 1)
        }
    }

    @MainActor
    func testDirectSpotRevealKeepsSongPresentedAndRemovesOutgoingSheetSnapshot() async {
        let sheet = SheetProvider()
        sheet.show(Spot.preview)
        let stream = ShazamStream.preview
        let transition = SheetRevealTransition()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        let detail = UIHostingController(rootView:
            Text("Spot")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { SheetRevealTransition.Anchor(transition: transition) }
        )
        detail.modalPresentationStyle = .pageSheet
        let presented = expectation(description: "Spot sheet presented")
        presenter.present(detail, animated: false) { presented.fulfill() }
        await fulfillment(of: [presented], timeout: 3)
        detail.view.layoutIfNeeded()
        let rendered = expectation(description: "Spot sheet rendered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { rendered.fulfill() }
        await fulfillment(of: [rendered], timeout: 3)
        let originalSubviewCount = window.subviews.count

        transition.reveal { sheet.show(stream) }

        XCTAssertEqual(window.subviews.count, originalSubviewCount + 1,
                       "The outgoing Spot must cover SongView until its dismissal animation")
        XCTAssertEqual(sheet.now, .stream(stream))
        let animationFinished = expectation(description: "Spot reveal finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { animationFinished.fulfill() }
        await fulfillment(of: [animationFinished], timeout: 3)
        XCTAssertEqual(window.subviews.count, originalSubviewCount)
        XCTAssertTrue(sheet.isPresented)
        sheet.isPresentedBinding.wrappedValue = false
        XCTAssertEqual(sheet.now, .none, "Dismissing Song returns to the main sheet")
        presenter.dismiss(animated: false)
        window.isHidden = true
    }

    @MainActor
    private final class PreviewCommitAnimator: NSObject, UIContextMenuInteractionCommitAnimating {
        let previewViewController: UIViewController? = nil
        var preferredCommitStyle: UIContextMenuInteractionCommitStyle = .pop
        var completions: [() -> Void] = []

        func addAnimations(_ animations: @escaping () -> Void) {}

        func addCompletion(_ completion: @escaping () -> Void) {
            completions.append(completion)
        }
    }

    func testShazamDaemonExitRetriesWithBoundedBackoff() {
        let connection = NSError(domain: NSCocoaErrorDomain, code: 4099)
        let reported = NSError(domain: SHErrorDomain, code: 202,
                               userInfo: [NSUnderlyingErrorKey: connection])
        var recovery = ShazamRecoveryPolicy()
        XCTAssertEqual(recovery.retryDelay(for: reported), .seconds(1))
        XCTAssertEqual(recovery.retryDelay(for: reported), .seconds(2))
        XCTAssertNil(recovery.retryDelay(for: reported), "A persistent failure must reach the normal error UI")

        var nextListen = ShazamRecoveryPolicy()
        XCTAssertEqual(nextListen.retryDelay(for: reported), .seconds(1))
    }

    func testShazamRecoveryRecognizesWrappedAndDirectServiceFailures() {
        for code in [CocoaError.Code.xpcConnectionInvalid, .xpcConnectionInterrupted] {
            let connection = NSError(domain: NSCocoaErrorDomain, code: code.rawValue)
            XCTAssertTrue(ShazamRecoveryPolicy.isServiceFailure(connection))
            let wrapped = NSError(domain: SHErrorDomain, code: SHError.Code.internalError.rawValue,
                                  userInfo: [NSUnderlyingErrorKey: connection])
            XCTAssertTrue(ShazamRecoveryPolicy.isServiceFailure(wrapped))
        }
        // 202 also covers transient catalog-server failures without a Cocoa error.
        XCTAssertTrue(ShazamRecoveryPolicy.isServiceFailure(
            NSError(domain: SHErrorDomain, code: SHError.Code.matchAttemptFailed.rawValue)))
    }

    func testShazamRecoveryDoesNotRetryUnrelatedErrorsOrSpendTheirBudget() {
        var recovery = ShazamRecoveryPolicy()
        for error in [
            NSError(domain: SHErrorDomain, code: SHError.Code.signatureDurationInvalid.rawValue),
            NSError(domain: SHErrorDomain, code: SHError.Code.invalidAudioFormat.rawValue),
            NSError(domain: SHErrorDomain, code: SHError.Code.internalError.rawValue),
            NSError(domain: NSURLErrorDomain, code: 202),
            NSError(domain: "unrelated", code: 4099)
        ] {
            XCTAssertNil(recovery.retryDelay(for: error))
        }
        XCTAssertEqual(recovery.retryDelay(for: NSError(domain: SHErrorDomain, code: 202)), .seconds(1))
    }

    func testVersionMatchingIgnoresCaseAccentsAndPunctuation() {
        XCTAssertTrue(SongVersionMatcher.isMatch(
            title: "DEJA VU!", artist: "BEYONCE",
            originalTitle: "Déjà Vu", originalArtist: "Beyoncé"))
    }

    func testVersionMatchingAllowsAlternateVersions() {
        XCTAssertEqual(SongVersionMatcher.searchQuery(title: "Song - 2011 Remaster", artist: "Artist"), "Song Artist")
        for title in ["Song - 2011 Remaster", "Song (Remastered)", "Song [Live Version]"] {
            XCTAssertTrue(SongVersionMatcher.isMatch(
                title: title, artist: "Artist", originalTitle: "Song", originalArtist: "Artist"), title)
            XCTAssertTrue(SongVersionMatcher.isMatch(
                title: title, artist: "Artist", originalTitle: title, originalArtist: "Artist"), title)
        }
    }

    func testVersionMatchingRejectsDifferentSongsAndArtists() {
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "Song", artist: "Cover Artist", originalTitle: "Song", originalArtist: "Original Artist"))
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "Other Song", artist: "Artist", originalTitle: "Song", originalArtist: "Artist"))
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "Song", artist: "Artist", originalTitle: "Song (Forever)", originalArtist: "Artist"))
    }

    func testVersionMatchingKeepsFeaturedArtistNames() {
        XCTAssertTrue(SongVersionMatcher.isMatch(
            title: "Song (feat. Guest) - Remastered", artist: "Artist",
            originalTitle: "Song (feat. Guest)", originalArtist: "Artist"))
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "Song (feat. Other) - Remastered", artist: "Artist",
            originalTitle: "Song (feat. Guest)", originalArtist: "Artist"))
    }

    func testVersionMatchingRejectsMissingIdentity() {
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "", artist: "Artist", originalTitle: "", originalArtist: "Artist"))
        XCTAssertFalse(SongVersionMatcher.isMatch(
            title: "Song", artist: "", originalTitle: "Song", originalArtist: ""))
    }

    @MainActor
    func testUnavailableSongMetadataIsSilentButUserActionsReportErrors() async throws {
        var lookupCount = 0
        var playbackCount = 0
        var errors: [String] = []
        let music = MusicProvider(catalogLookup: { _ in
            lookupCount += 1
            throw MusicProvider.MusicError.songUnavailable
        }, startQueuedPlayback: {
            playbackCount += 1
        })
        music.authorizationStatus = .authorized
        music.onPlaybackError = { errors.append($0) }

        let song = try await music.fetchTrackInfo("missing-song")
        XCTAssertNil(song)
        XCTAssertTrue(music.isSongUnavailable("missing-song"))
        XCTAssertTrue(errors.isEmpty, "Opening an unavailable song should be quiet")

        let nextQueued = await music.queue(ids: ["missing-song"], position: .afterCurrentEntry)
        let laterQueued = await music.queue(ids: ["missing-song"], position: .tail)
        await music.play(id: "missing-song")

        XCTAssertFalse(nextQueued)
        XCTAssertFalse(laterQueued)
        XCTAssertEqual(errors, Array(repeating: "Song unavailable", count: 3))
        XCTAssertEqual(lookupCount, 1)
        XCTAssertEqual(playbackCount, 0)
    }

    @MainActor
    func testEmptyCatalogResponseCannotAdvanceExistingQueue() async {
        var playbackCount = 0
        var errors: [String] = []
        let music = MusicProvider(catalogLookup: { _ in [] }, startQueuedPlayback: {
            playbackCount += 1
        })
        music.onPlaybackError = { errors.append($0) }

        await music.play(id: "missing-song")

        XCTAssertEqual(playbackCount, 0, "A failed insertion must not skip to an unrelated queued song")
        XCTAssertEqual(errors, ["Song unavailable"])
        XCTAssertTrue(music.isSongUnavailable("missing-song"))
    }

    @MainActor
    func testNetworkFailureDoesNotMarkSongUnavailableOrAdvanceQueue() async throws {
        var playbackCount = 0
        var errors: [String] = []
        let music = MusicProvider(catalogLookup: { _ in
            throw URLError(.notConnectedToInternet)
        }, startQueuedPlayback: {
            playbackCount += 1
        })
        music.authorizationStatus = .authorized
        music.onPlaybackError = { errors.append($0) }

        do {
            _ = try await music.fetchTrackInfo("available-song")
            XCTFail("Network failures must remain distinguishable from unavailable songs")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        await music.play(id: "available-song")

        XCTAssertFalse(music.isSongUnavailable("available-song"))
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(playbackCount, 0)
    }

    @MainActor
    func testCancelledLookupDoesNotMarkSongUnavailable() async {
        var errors: [String] = []
        let music = MusicProvider(catalogLookup: { _ in throw CancellationError() })
        music.authorizationStatus = .authorized
        music.onPlaybackError = { errors.append($0) }

        do {
            _ = try await music.fetchTrackInfo("available-song")
            XCTFail("Cancellation should propagate to the metadata task")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let queued = await music.queue(ids: ["available-song"])

        XCTAssertFalse(queued)
        XCTAssertFalse(music.isSongUnavailable("available-song"))
        XCTAssertTrue(errors.isEmpty)
    }

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
        stream.horizontalAccuracy = 400
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
        XCTAssertEqual(mapView.overlays.compactMap { $0 as? MKCircle }.first?.radius, 500)
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
    func testNestedSpotRestoresSpotAnnotationAndRemovesPulledOutSong() throws {
        let first = ShazamStream(title: "First song", latitude: 37.78, longitude: -122.4)
        let second = ShazamStream(title: "Second song", latitude: 37.79, longitude: -122.41)
        let spot = Spot(name: "Venue", latitude: 37.785, longitude: -122.405)
        first.spot = spot
        second.spot = spot
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext, sheetProvider: sheet
        )
        let map = MKMapView()
        coordinator.mapView = map
        coordinator.setupSheetProviderObservation()
        coordinator.syncAnnotations(shazams: [], spots: [spot])
        sheet.show(spot)

        for song in [first, second] {
            sheet.show(song)
            // A previous Spot sheet's dismissal must not override the new song.
            sheet.dismissSpotOnMap(spot)
            let pulledOut = try XCTUnwrap(coordinator.lastSelectedAnnotation as? ShazamAnnotation)
            XCTAssertEqual(pulledOut.shazamStream, song)
            XCTAssertEqual(map.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)

            sheet.showSpotOnMap(spot)
            XCTAssertEqual(sheet.now, .stream(song), "Keep SongView underneath SpotView")
            XCTAssertEqual(sheet.mapSelection, .spot(spot))
            XCTAssertEqual(sheet.coordinate?.latitude, spot.latitude)
            XCTAssertEqual((coordinator.lastSelectedAnnotation as? SpotAnnotation)?.spot, spot)
            XCTAssertTrue(map.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
            coordinator.syncAnnotations(shazams: [], spots: [spot])
            coordinator.mapView(map, didDeselect: pulledOut)
            XCTAssertEqual(sheet.now, .stream(song), "Ignore the removed song pin's delayed callback")
            XCTAssertEqual(sheet.mapSelection, .spot(spot))
            XCTAssertTrue(map.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
        }

        let spotAnnotation = try XCTUnwrap(coordinator.lastSelectedAnnotation as? SpotAnnotation)
        sheet.dismissSpotOnMap(spot)
        coordinator.mapView(map, didDeselect: spotAnnotation)
        XCTAssertEqual(sheet.now, .stream(second))
        XCTAssertEqual(sheet.mapSelection, .stream(second))
        XCTAssertEqual((coordinator.lastSelectedAnnotation as? ShazamAnnotation)?.shazamStream, second)
        XCTAssertEqual(map.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)

        sheet.showSpotOnMap(spot)
        sheet.now = .none
        XCTAssertEqual(sheet.mapSelection, .none)
        XCTAssertNil(sheet.coordinate)
        XCTAssertTrue(map.annotations.compactMap { $0 as? ShazamAnnotation }.isEmpty)
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
        XCTAssertEqual(view.collisionMode, .none)
        XCTAssertNil(view.clusteringIdentifier)
        XCTAssertTrue(map.overlays.isEmpty)
        coordinator.syncAnnotations(shazams: [song], spots: [spot])
        XCTAssertTrue(coordinator.lastSelectedAnnotation === selected)
        coordinator.mapView(map, didDeselect: normal)
        XCTAssertEqual(sheet.now, .stream(song))
        sheet.now = .none
        XCTAssertEqual(map.annotations.compactMap { $0 as? ShazamAnnotation }.count, 1)
        // Once assigned to a Spot, the song is absent from the normal map query.
        // Selecting it must still provide collision-free artwork above that Spot.
        song.spot = spot
        coordinator.syncAnnotations(shazams: [], spots: [spot])
        sheet.show(spot)
        sheet.show(song)
        let attachedSelection = try XCTUnwrap(coordinator.lastSelectedAnnotation as? ShazamAnnotation)
        let attachedView = try XCTUnwrap(coordinator.mapView(map, viewFor: attachedSelection))
        XCTAssertEqual(attachedView.collisionMode, .none)
        XCTAssertEqual(attachedView.selectedZPriority, .max)
        XCTAssertTrue(map.selectedAnnotations.contains { $0 === attachedSelection })
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
        var accuracyPermission: CLAccuracyAuthorization = .fullAccuracy
        var permission: CLAuthorizationStatus = .authorizedWhenInUse
        override var authorizationStatus: CLAuthorizationStatus { permission }
        override var accuracyAuthorization: CLAccuracyAuthorization { accuracyPermission }
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
        XCTAssertEqual(primary.desiredAccuracy, kCLLocationAccuracyNearestTenMeters,
                       "Continuous listening must request venue-level accuracy, not a 100m fix")
        provider.requestLocation()
        XCTAssertEqual(refresh.desiredAccuracy, kCLLocationAccuracyBest)
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
    func testPreciseAcquisitionWaitsPastCoarseFixWithoutRestartingBackgroundSession() {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        location.startBackgroundLocationUpdates()
        location.requestPreciseLocation()
        XCTAssertEqual(refresh.startCount, 1)
        XCTAssertEqual(refresh.desiredAccuracy, kCLLocationAccuracyBest)
        let coarse = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4),
                                altitude: 0, horizontalAccuracy: 150, verticalAccuracy: -1, timestamp: .now)
        location.locationManager(refresh, didUpdateLocations: [coarse])
        location.locationManager(refresh, didFailWithError: NSError(domain: kCLErrorDomain,
            code: CLError.locationUnknown.rawValue))
        location.requestPreciseLocation()
        location.requestLocation()
        XCTAssertEqual(refresh.startCount, 1, "Coalesce acquisition across multiple matches")
        XCTAssertEqual(refresh.requestCount, 0)
        XCTAssertEqual(refresh.stopCount, 0, "The first coarse result must not end precise acquisition")
        let precise = CLLocation(coordinate: coarse.coordinate, altitude: 0,
                                 horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: .now)
        location.locationManager(refresh, didUpdateLocations: [precise])
        XCTAssertEqual(refresh.stopCount, 1)
        XCTAssertEqual(location.currentLocation?.horizontalAccuracy, 8)
        XCTAssertEqual(primary.stopCount, 0)
        location.stopBackgroundLocationUpdates()
    }

    @MainActor
    func testPreciseAcquisitionRespectsApproximatePermissionAndStopsWithSession() {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        primary.accuracyPermission = .reducedAccuracy
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        location.startBackgroundLocationUpdates()
        location.requestPreciseLocation()
        XCTAssertEqual(primary.desiredAccuracy, kCLLocationAccuracyReduced)
        XCTAssertEqual(refresh.startCount, 0)
        primary.accuracyPermission = .fullAccuracy
        location.requestPreciseLocation()
        XCTAssertEqual(refresh.startCount, 1)
        location.stopBackgroundLocationUpdates()
        location.requestLocation()
        XCTAssertEqual(primary.requestCount, 1, "Ending acquisition must release its in-flight guard")
    }

    private final class StationaryActivity: CMMotionActivity {
        let beganAt: Date
        init(since date: Date) { beganAt = date; super.init() }
        required init?(coder: NSCoder) { fatalError("Not used by tests") }
        override var stationary: Bool { true }
        override var confidence: CMMotionActivityConfidence { .high }
        override var startDate: Date { beganAt }
    }

    @MainActor
    func testLaterPreciseFixRepairsEarlyContinuousSongsOnlyWithStationaryEvidence() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        let motion = MotionProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: motion, sheet: SheetProvider())
        let firstMatch = Date().addingTimeInterval(-240)
        motion.currentActivity = StationaryActivity(since: firstMatch.addingTimeInterval(-60))
        let spot = Spot(name: "Stationary venue", latitude: 37.78, longitude: -122.4)
        context.insert(spot)
        var songs: [ShazamStream] = []
        for index in 0..<4 {
            let matchedAt = firstMatch.addingTimeInterval(Double(index) * 45)
            let song = ShazamStream(title: "Early match \(index)", latitude: spot.latitude, longitude: spot.longitude)
            song.timestamp = matchedAt
            song.horizontalAccuracy = 150
            song.locationObservedAt = matchedAt.addingTimeInterval(-1)
            song.city = "San Francisco"
            context.insert(song)
            songs.append(song)
        }
        try context.save()
        for song in songs { provider.trackLocationRecovery(for: song, matchedAt: song.timestamp) }
        XCTAssertEqual(refresh.startCount, 1, "Approximate matches with labels must actively request precision")
        // A placemark arriving after 30 seconds must not discard recovery for
        // earlier stationary matches while GPS is still acquiring precision.
        let coarseFix = CLLocation(coordinate: spot.coordinate, altitude: 0,
                                   horizontalAccuracy: 150, verticalAccuracy: -1, timestamp: .now)
        location.currentLocation = coarseFix
        location.acceptPlacemark(MKPlacemark(coordinate: coarseFix.coordinate,
            addressDictionary: ["City": "San Francisco"]), for: coarseFix)
        provider.resolvePendingMatchLocations(at: .now)
        let precise = CLLocation(coordinate: spot.coordinate, altitude: 0,
                                 horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: .now)
        location.currentLocation = precise
        motion.currentActivity = nil
        provider.resolvePendingMatchLocations(at: .now)
        for song in songs {
            XCTAssertNotNil(song.approximateLocationRadius)
            XCTAssertNil(song.spot, "A later fix without motion history cannot prove an earlier venue")
        }
        motion.currentActivity = StationaryActivity(since: firstMatch.addingTimeInterval(-60))
        primary.accuracyPermission = .reducedAccuracy
        provider.resolvePendingMatchLocations(at: .now)
        for song in songs {
            XCTAssertNotNil(song.approximateLocationRadius)
            XCTAssertNil(song.spot, "Stationary evidence must not bypass Approximate Location permission")
        }
        primary.accuracyPermission = .fullAccuracy
        provider.resolvePendingMatchLocations(at: .now)
        for song in songs {
            XCTAssertNil(song.approximateLocationRadius)
            XCTAssertEqual(song.horizontalAccuracy, 8)
            XCTAssertEqual(song.spot?.persistentModelID, spot.persistentModelID)
        }
        location.stopBackgroundLocationUpdates()
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
        XCTAssertEqual(refresh.startCount, 1)
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
        var feedbackCount = 0
        let provider = ShazamProvider(saveMatchContext: { context in
            if shouldFail { throw SaveFailure.simulated }
            try context.save()
        }, matchFeedback: { feedbackCount += 1 })
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
        XCTAssertEqual(feedbackCount, 0, "Failed writes must not signal a successful capture")
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
        let expectedFeedbackCount = provider.appIsForeground ? 1 : 0
        XCTAssertEqual(feedbackCount, expectedFeedbackCount)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ShazamStream>()), 1)
        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertEqual(saved.latitude, fix.coordinate.latitude)
        XCTAssertEqual(saved.city, "San Francisco")
        provider.retryPendingMatches()
        XCTAssertEqual(savedCount, 1)
        XCTAssertEqual(feedbackCount, expectedFeedbackCount, "Retrying a saved capture must not repeat its haptic")
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
    func testReplayAfterBriefCaptureNearStartIsRecognized() {
        let provider = ShazamProvider()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        provider.recordSuccessfulMatch(title: "Song", artist: "Artist", at: start,
                                      shazamID: "a", playbackPosition: 3)
        XCTAssertFalse(provider.shouldRecordMatch(title: "Song", artist: "Artist",
            at: start.addingTimeInterval(600), shazamID: "a", playbackPosition: 1))
        XCTAssertTrue(provider.shouldRecordMatch(title: "Song", artist: "Artist",
            at: start.addingTimeInterval(603), shazamID: "a", playbackPosition: 4))
    }

    @MainActor
    func testMapPinTapThenDeselectClosesSongView() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let stream = ShazamStream(title: "Song", latitude: 37.7, longitude: -122.4)
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext, sheetProvider: sheet)
        let map = MKMapView()
        coordinator.mapView = map
        coordinator.setupSheetProviderObservation()
        coordinator.syncAnnotations(shazams: [stream], spots: [])
        let normal = try XCTUnwrap(map.annotations.compactMap { $0 as? ShazamAnnotation }.first)
        map.selectAnnotation(normal, animated: false)
        coordinator.mapView(map, didSelect: normal)
        let selected = try XCTUnwrap(map.selectedAnnotations.first)
        XCTAssertFalse(selected === normal)
        XCTAssertTrue(coordinator.lastSelectedAnnotation === selected)
        map.deselectAnnotation(selected, animated: false)
        coordinator.mapView(map, didDeselect: selected)
        XCTAssertEqual(sheet.now, .none)
    }

    private final class AnnotationReadSpyMapView: MKMapView {
        var annotationReads = 0
        var onDeselect: (() -> Void)?
        override var annotations: [any MKAnnotation] {
            annotationReads += 1
            return super.annotations
        }
        override func deselectAnnotation(_ annotation: (any MKAnnotation)?, animated: Bool) {
            onDeselect?()
            super.deselectAnnotation(annotation, animated: animated)
        }
    }

    @MainActor
    func testForeignDeselectionDoesNotInspectMapKitAnnotationStorage() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext, sheetProvider: sheet)
        let map = AnnotationReadSpyMapView()
        coordinator.mapView = map
        let song = ShazamStream(title: "Still selected", latitude: 37.78, longitude: -122.4)
        sheet.show(song)
        let readsBeforeCallback = map.annotationReads
        coordinator.mapView(map, didDeselect: MKPointAnnotation())
        XCTAssertEqual(map.annotationReads, readsBeforeCallback)
        XCTAssertEqual(sheet.now, .stream(song))
    }

    @MainActor
    func testClusterProgrammaticDeselectionIsSuppressedAndNotRetained() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let sheet = SheetProvider()
        let coordinator = MapViewControllerRepresentable.Coordinator(
            modelContext: container.mainContext, sheetProvider: sheet)
        let map = AnnotationReadSpyMapView()
        coordinator.mapView = map
        var deselectCount = 0
        map.onDeselect = {
            deselectCount += 1
            XCTAssertTrue(coordinator.isProgrammaticSelection)
            coordinator.mapView(map, didDeselect: MKPointAnnotation())
        }
        defer { map.onDeselect = nil }
        let song = ShazamStream(title: "Cluster member", latitude: 37.78, longitude: -122.4)
        let cluster = MKClusterAnnotation(memberAnnotations: [ShazamAnnotation(shazamStream: song)])
        coordinator.mapView(map, didSelect: cluster)
        XCTAssertEqual(deselectCount, 1)
        XCTAssertFalse(coordinator.isProgrammaticSelection)
        XCTAssertFalse(coordinator.lastSelectedAnnotation === cluster)
    }

    @MainActor
    func testEarlyPreciseFixAttachesSpotAndUpgradesCoarseColdStart() async throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let location = LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy())
        let motion = MotionProvider()
        let provider = ShazamProvider()
        provider.configure(modelContext: context, location: location, motion: motion, sheet: SheetProvider())
        let spot = Spot(name: "Venue", latitude: 37.78, longitude: -122.4)
        context.insert(spot)
        let matchedAt = Date()
        let missing = ShazamStream(title: "Cold GPS", latitude: 0, longitude: 0)
        missing.timestamp = matchedAt
        let coarse = ShazamStream(title: "Coarse first fix", latitude: 37.781, longitude: -122.4)
        coarse.timestamp = matchedAt
        coarse.horizontalAccuracy = 500
        coarse.locationObservedAt = matchedAt.addingTimeInterval(-1)
        coarse.city = "San Francisco"
        context.insert(missing)
        context.insert(coarse)
        try context.save()
        provider.trackLocationRecovery(for: missing, matchedAt: matchedAt)
        provider.trackLocationRecovery(for: coarse, matchedAt: matchedAt)
        let fix = CLLocation(coordinate: spot.coordinate, altitude: 0, horizontalAccuracy: 8,
                             verticalAccuracy: -1, timestamp: matchedAt.addingTimeInterval(5))
        // Exercise MapKit's fix feed, not just assigning the provider's cache.
        location.acceptMapLocation(fix)
        await Task.yield()
        provider.resolvePendingMatchLocations(at: matchedAt.addingTimeInterval(6))
        for song in [missing, coarse] {
            XCTAssertNil(song.approximateLocationRadius)
            XCTAssertEqual(song.horizontalAccuracy, 8)
            XCTAssertEqual(song.locationObservedAt, fix.timestamp)
            XCTAssertEqual(song.spot?.persistentModelID, spot.persistentModelID)
        }
    }

    func testEarlyPreciseFixGraceDoesNotUpgradeMovingOrCoarseLocations() {
        for motion in ["automotive", "cycling", "running", "walking"] {
            XCTAssertFalse(ShazamStream.acceptsEarlyPreciseFix(accuracy: 5, speed: -1,
                motionActivity: motion, delay: 2))
        }
        XCTAssertFalse(ShazamStream.acceptsEarlyPreciseFix(accuracy: 500, speed: 0, motionActivity: nil, delay: 2))
        XCTAssertFalse(ShazamStream.acceptsEarlyPreciseFix(accuracy: 5, speed: 10, motionActivity: nil, delay: 2))
        XCTAssertFalse(ShazamStream.acceptsEarlyPreciseFix(accuracy: 5, speed: 0, motionActivity: nil, delay: 20))
    }

    @MainActor
    func testRecentPreciseMapFixCanRefineSlightlyNewerCoarseFix() {
        let location = LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy())
        let now = Date()
        location.currentLocation = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 500, verticalAccuracy: -1, timestamp: now)
        let precise = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 6, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-2))
        location.acceptMapLocation(precise)
        XCTAssertEqual(location.currentLocation?.timestamp, precise.timestamp)
        XCTAssertEqual(location.currentLocation?.horizontalAccuracy, 6)
        location.acceptMapLocation(CLLocation(coordinate: precise.coordinate, altitude: 0,
            horizontalAccuracy: 1, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-60)))
        XCTAssertEqual(location.currentLocation?.timestamp, precise.timestamp)
    }

    @MainActor
    func testNotificationArtworkUsesExistingImageCacheWithoutNetwork() async throws {
        let url = URL(string: "https://cache-test.invalid/\(UUID().uuidString).png")!
        let image = UIGraphicsImageRenderer(size: .init(width: 8, height: 8)).image { context in
            UIColor.blue.setFill()
            context.fill(.init(x: 0, y: 0, width: 8, height: 8))
        }
        ImageCache.default.store(image, forKey: url.cacheKey, toDisk: false, completionHandler: nil)
        let result = await MatchNotificationService.shared.artworkAttachment(from: url)
        let attachment = try XCTUnwrap(result)
        XCTAssertEqual(attachment.0.identifier, "artwork")
        try? FileManager.default.removeItem(at: attachment.1)
        try await ImageCache.default.removeImage(forKey: url.cacheKey, fromDisk: false)
    }

    func testOldLiveActivityPayloadDecodesWithDefaults() throws {
        let data = Data(#"{"takingTooLong":true}"#.utf8)
        let state = try JSONDecoder().decode(WidgetAttributes.ContentState.self, from: data)
        XCTAssertTrue(state.takingTooLong)
        XCTAssertFalse(state.continuous)
        XCTAssertEqual(state.matchCount, 0)
        XCTAssertNil(state.locationName)
        let current = WidgetAttributes.ContentState(takingTooLong: false, continuous: true,
            matchCount: 7, locationName: "Mission", matchedTitle: "Song", matchedArtist: "Artist")
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

    @MainActor
    func testForegroundAcquisitionWaitsForPermissionAndCoalescesLaunchRequests() {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        primary.permission = .notDetermined
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        location.beginForegroundAcquisition()
        XCTAssertEqual(refresh.startCount, 0)
        primary.permission = .authorizedWhenInUse
        location.locationManagerDidChangeAuthorization(primary)
        XCTAssertEqual(refresh.startCount, 1)
        location.beginForegroundAcquisition()
        location.requestLocation()
        XCTAssertEqual(refresh.startCount, 1)
        XCTAssertEqual(primary.requestCount, 0)
        location.stopBackgroundLocationUpdates()
    }

    @MainActor
    func testRecognitionCanEndWithoutCancellingPreciseAcquisition() {
        let primary = LocationManagerSpy()
        let refresh = LocationManagerSpy()
        let location = LocationProvider(locationManager: primary, refreshLocationManager: refresh)
        location.startBackgroundLocationUpdates()
        location.requestPreciseLocation()
        location.stopBackgroundLocationUpdates(preservePreciseAcquisition: true)
        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(refresh.stopCount, 0)
        XCTAssertTrue(refresh.allowsBackgroundLocationUpdates)
        let fix = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4), altitude: 0,
                             horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: .now)
        location.locationManager(refresh, didUpdateLocations: [fix])
        XCTAssertEqual(refresh.stopCount, 1)
        XCTAssertFalse(refresh.allowsBackgroundLocationUpdates)
    }

    @MainActor
    func testProvisionalPinKeepsUncertaintyWithoutShowingAreaOrAssigningSpot() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let song = ShazamStream(title: "Provisional", latitude: 37.78, longitude: -122.4)
        song.horizontalAccuracy = 120
        song.locationObservedAt = song.timestamp
        let spot = Spot(name: "Nearby", latitude: song.latitude, longitude: song.longitude)
        container.mainContext.insert(song)
        container.mainContext.insert(spot)
        song.spotIt(context: container.mainContext)
        XCTAssertEqual(song.approximateLocationRadius, 120)
        XCTAssertNil(song.displayedApproximateLocationRadius)
        XCTAssertFalse(song.needsLocationCorrection)
        XCTAssertNil(ShazamAnnotation(shazamStream: song).approximateRadius)
        XCTAssertNil(song.spot)
        song.horizontalAccuracy = 250
        XCTAssertEqual(song.displayedApproximateLocationRadius, 250)
        XCTAssertTrue(song.needsLocationCorrection)
        song.horizontalAccuracy = 120
        song.locationAccuracyReduced = true
        XCTAssertEqual(song.displayedApproximateLocationRadius, 250)
        XCTAssertTrue(song.needsLocationCorrection)
    }

    @MainActor
    func testPreciseDrivingFixAfterMatchKeepsSmallUncertaintyWithoutCorrectionAction() {
        let song = ShazamStream(title: "Driving match", latitude: 37.78, longitude: -122.4)
        song.horizontalAccuracy = 2.0086828677281354
        song.locationObservedAt = song.timestamp.addingTimeInterval(0.818117)
        song.motionActivity = "automotive"
        song.speed = 7.627748454865984
        XCTAssertEqual(song.approximateLocationRadius, 50)
        XCTAssertNil(song.displayedApproximateLocationRadius)
        XCTAssertFalse(song.needsLocationCorrection)
    }

    @MainActor
    func testMissingCoordinatesStillOfferLocationCorrection() {
        let song = ShazamStream(title: "Missing", latitude: 0, longitude: 0)
        XCTAssertTrue(song.needsLocationCorrection)
        song.latitude = -1
        song.longitude = -1
        XCTAssertTrue(song.needsLocationCorrection)
        song.latitude = 37.78
        song.longitude = -122.4
        XCTAssertFalse(song.needsLocationCorrection)
    }

    @MainActor
    func testProvisionalPinImprovesInStagesAndRecoverySurvivesReopening() throws {
        let container = try ModelContainer(for: ShazamStream.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let matchedAt = Date()
        let song = ShazamStream(title: "Refining", latitude: 37.78, longitude: -122.4)
        song.timestamp = matchedAt
        song.horizontalAccuracy = 500
        song.locationObservedAt = matchedAt
        song.city = "San Francisco"
        context.insert(song)
        try context.save()
        let firstLocation = LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy())
        let firstProvider = ShazamProvider()
        firstProvider.configure(modelContext: context, location: firstLocation, motion: MotionProvider(), sheet: SheetProvider())
        firstProvider.trackLocationRecovery(for: song, matchedAt: matchedAt)
        XCTAssertTrue(song.locationRecoveryPending)

        let reopenedContext = ModelContext(container)
        let refreshedSong = try XCTUnwrap(reopenedContext.fetch(FetchDescriptor<ShazamStream>()).first)
        XCTAssertTrue(refreshedSong.locationRecoveryPending, "Recovery must be durably saved")
        let location = LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy())
        let provider = ShazamProvider()
        provider.configure(modelContext: reopenedContext, location: location, motion: MotionProvider(), sheet: SheetProvider())
        location.currentLocation = CLLocation(coordinate: .init(latitude: 37.7801, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 120, verticalAccuracy: -1, timestamp: matchedAt.addingTimeInterval(2))
        provider.resolvePendingMatchLocations(at: matchedAt.addingTimeInterval(3))
        XCTAssertEqual(refreshedSong.horizontalAccuracy, 120)
        XCTAssertNil(refreshedSong.displayedApproximateLocationRadius)
        XCTAssertNotNil(refreshedSong.approximateLocationRadius)
        location.currentLocation = CLLocation(coordinate: .init(latitude: 37.7802, longitude: -122.4),
            altitude: 0, horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: matchedAt.addingTimeInterval(5))
        provider.resolvePendingMatchLocations(at: matchedAt.addingTimeInterval(6))
        XCTAssertEqual(refreshedSong.latitude, 37.7802)
        XCTAssertNil(refreshedSong.approximateLocationRadius)
        firstLocation.stopBackgroundLocationUpdates()
        location.stopBackgroundLocationUpdates()
    }

    @MainActor
    func testWorseNewerFixCannotReplaceFreshPreciseCache() {
        let location = LocationProvider(locationManager: LocationManagerSpy(), refreshLocationManager: LocationManagerSpy())
        let now = Date()
        let precise = CLLocation(coordinate: .init(latitude: 37.78, longitude: -122.4), altitude: 0,
            horizontalAccuracy: 8, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-2))
        location.currentLocation = precise
        location.acceptMapLocation(CLLocation(coordinate: precise.coordinate, altitude: 0,
            horizontalAccuracy: 500, verticalAccuracy: -1, timestamp: now))
        XCTAssertEqual(location.currentLocation?.horizontalAccuracy, 8)
        XCTAssertEqual(location.currentLocation?.timestamp, precise.timestamp)
    }
}
