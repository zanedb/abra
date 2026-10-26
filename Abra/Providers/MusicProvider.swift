//
//  MusicProvider.swift
//  Abra
//

import Foundation
import MediaPlayer
import MusicKit
import StoreKit
import SwiftData

@MainActor @Observable class MusicProvider {
    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    let musicKitPlayer = SystemMusicPlayer.shared

    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var subscribed: Bool = false

    private(set) var nowPlaying: String?
    private(set) var lastPlayed: String?
    private(set) var errorMessage: String?
    private var previewPlayer: AVPlayer?
    private(set) var unavailableSongIDs: Set<String> = []
    private var trackMetadata: [String: Song] = [:]
    @ObservationIgnored var onPlaybackError: (@MainActor (String) -> Void)?
    @ObservationIgnored private let catalogLookup: ([String]) async throws -> MusicItemCollection<Song>
    @ObservationIgnored private let startQueuedPlayback: () async throws -> Void

    init(
        catalogLookup: @escaping ([String]) async throws -> MusicItemCollection<Song> = MusicProvider.lookupCatalogSongs,
        startQueuedPlayback: @escaping () async throws -> Void = {
            try await SystemMusicPlayer.shared.skipToNextEntry()
            MPMusicPlayerController.systemMusicPlayer.play()
        }
    ) {
        self.catalogLookup = catalogLookup
        self.startQueuedPlayback = startQueuedPlayback
        setupNotifications()

        Task {
            if let subscription = try? await MusicSubscription.current {
                subscribed = subscription.canPlayCatalogContent
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        musicPlayer.beginGeneratingPlaybackNotifications()
    }

    @objc private func playbackStateChanged() {
        Task { @MainActor in
            nowPlaying =
                musicPlayer.playbackState == .playing
                ? musicPlayer.nowPlayingItem?.playbackStoreID : nil
            lastPlayed = musicPlayer.nowPlayingItem?.playbackStoreID
        }
    }

    @objc private func previewDidFinishPlaying(_ notification: Notification) {
        stopPreviewPlayback()
    }

    // MARK: - Playback

    /// Play/pause according to whether ID is currently being played
    func playPause(id: String) {
        playPause(ids: [id])
    }

    /// Play/pause according to whether IDs are currently being played
    func playPause(ids: [String]) {
        Task {
            if ids.count == 1, isSongUnavailable(ids.first) {
                reportSongUnavailable()
                return
            }
            if !subscribed {
                await handlePreviewPlayback(ids: ids)
                return
            }
            await handleFullPlayback(ids: ids)
        }
    }

    private func handlePreviewPlayback(ids: [String]) async {
        if let now = nowPlaying, !ids.contains(now) {
            if let firstId = ids.first {
                await playPreview(for: firstId)
            }
            return
        }
        if nowPlaying != nil {
            stopPreviewPlayback()
        } else if let firstId = ids.first {
            await playPreview(for: firstId)
        }
    }

    private func handleFullPlayback(ids: [String]) async {
        if let now = nowPlaying, !ids.contains(now) {
            await play(ids: ids)
            return
        }
        if nowPlaying != nil {
            stopPlayback()
        } else {
            await play(ids: ids)
        }
    }

    func play(id: String) async {
        await play(ids: [id])
    }

    func play(ids: [String]) async {
        guard !ids.isEmpty else { return }
        if ids.count == 1, isSongUnavailable(ids.first) {
            reportSongUnavailable()
            return
        }
        if lastPlayed == ids.first {
            // Resume if currently playing song is requested
            musicPlayer.play()
            return
        }

        do {
            // Play next, skip one
            guard await queue(ids: ids, position: .afterCurrentEntry) else { return }
            try await startQueuedPlayback()
        } catch {
            print("Error playing: \(error)")
        }
    }

    func stopPlayback() {
        musicPlayer.pause()
    }

    // MARK: - Queue

    @discardableResult
    func queue(
        ids: [String],
        position: MusicKit.MusicPlayer.Queue.EntryInsertionPosition = .tail
    ) async -> Bool {
        guard !ids.isEmpty else { return false }
        let requestedIDs = ids.filter { !isSongUnavailable($0) }
        guard !requestedIDs.isEmpty else {
            reportSongUnavailable()
            return false
        }

        do {
            let songs = try await catalogLookup(requestedIDs)
            try Task.checkCancellation()
            let returnedIDs = Set(songs.map { $0.id.rawValue })
            unavailableSongIDs.formUnion(Set(requestedIDs).subtracting(returnedIDs))
            unavailableSongIDs.subtract(returnedIDs)
            guard !songs.isEmpty else {
                reportSongUnavailable()
                return false
            }
            try await musicKitPlayer.queue.insert(songs, position: position)
            return true
        } catch {
            if !Task.isCancelled, case MusicError.songUnavailable = error {
                if requestedIDs.count == 1 {
                    unavailableSongIDs.formUnion(requestedIDs)
                }
                reportSongUnavailable()
            }
            print("Error inserting songs into queue: \(error)")
            return false
        }
    }

    // MARK: - Preview Playback

    /// Use AVPlayer to play the preview for non-subscribers
    func playPreview(for trackId: String) async {
        do {
            guard let song = try await fetchTrackInfo(trackId) else {
                reportSongUnavailable()
                return
            }
            guard let previewURL = song.previewAssets?.first?.url else {
                print("No preview available for track ID: \(trackId)")
                return
            }
            let playerItem = AVPlayerItem(url: previewURL)

            // For tracking end of playback
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: previewPlayer?.currentItem
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(previewDidFinishPlaying(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )

            // Reuse or create the AVPlayer
            if let player = previewPlayer {
                player.replaceCurrentItem(with: playerItem)
                player.play()
            } else {
                previewPlayer = AVPlayer(playerItem: playerItem)
                previewPlayer?.play()
            }
            nowPlaying = trackId
        } catch {
            print("Error fetching preview: \(error)")
        }
    }

    func stopPreviewPlayback() {
        nowPlaying = nil
        previewPlayer?.pause()
        previewPlayer?.replaceCurrentItem(with: nil)
    }

    // MARK: - Authorization

    func requestPermission() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status != .authorized {
            Task { @MainActor in
                errorMessage = "Music playback is not authorized."
            }
        }
    }

    // MARK: - Track Info

    /// Fetches track information from Apple Music using the track ID
    /// - Parameter trackId: The Apple Music ID for the track
    /// - Returns: MusicItemCollection<Song> Element with a bunch of metadata
    @discardableResult
    func fetchTrackInfo(_ trackId: String) async throws -> MusicItemCollection<
        Song
    >.Element? {
        guard !isSongUnavailable(trackId) else { return nil }
        if let cached = trackMetadata[trackId] { return cached }
        if authorizationStatus == .notDetermined {
            await requestPermission()
        }
        do {
            let songs = try await catalogLookup([trackId])
            try Task.checkCancellation()
            guard let song = songs.first else {
                unavailableSongIDs.insert(trackId)
                return nil
            }
            unavailableSongIDs.remove(trackId)
            trackMetadata[trackId] = song
            return song
        } catch {
            if !Task.isCancelled, case MusicError.songUnavailable = error {
                unavailableSongIDs.insert(trackId)
                return nil
            }
            throw error
        }
    }

    func isSongUnavailable(_ id: String?) -> Bool {
        guard let id else { return false }
        return unavailableSongIDs.contains(id)
    }

    func cachedTrackInfo(_ id: String?) -> Song? {
        guard let id, !isSongUnavailable(id) else { return nil }
        return trackMetadata[id]
    }

    /// Persist in an isolated context before updating the SwiftUI-bound instance.
    /// Failed saves must not change the displayed version or discard unsaved notes.
    func relink(_ stream: ShazamStream, to song: Song) throws {
        guard let owner = stream.modelContext, !stream.isDeleted else {
            throw MusicError.songNoLongerSaved
        }
        let id = stream.persistentModelID
        let editingContext = ModelContext(owner.container)
        editingContext.autosaveEnabled = false
        let descriptor = FetchDescriptor<ShazamStream>(predicate: #Predicate { $0.persistentModelID == id })
        guard let copy = try editingContext.fetch(descriptor).first else {
            throw MusicError.songNoLongerSaved
        }

        applyVersion(song, to: copy)
        try editingContext.save()

        // Publish the complete catalog metadata before dismissing the picker.
        trackMetadata[song.id.rawValue] = song
        unavailableSongIDs.remove(song.id.rawValue)
        applyVersion(song, to: stream)
    }

    private func applyVersion(_ song: Song, to stream: ShazamStream) {
        stream.appleMusicID = song.id.rawValue
        stream.appleMusicURL = song.url ?? URL(string: "https://music.apple.com/song/\(song.id.rawValue)")
        stream.title = song.title
        stream.artist = song.artistName
        // There are no catalog equivalents for these old version-specific values.
        stream.subtitle = nil
        stream.videoURL = nil
        stream.artworkURL = song.artwork?.url(width: 600, height: 600)
            ?? URL(string: "https://zane.link/abra-unavailable")!
        stream.isExplicit = song.contentRating == .explicit
        stream.isrc = song.isrc
        // Preserve capture date, location, notes, Spot, and Shazam provenance.
    }

    func searchSongs(query: String) async throws -> [Song] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 25
        let response = try await request.response()
        try Task.checkCancellation()
        return response.songs.filter { !isSongUnavailable($0.id.rawValue) }
    }

    private func reportSongUnavailable() {
        onPlaybackError?("Song unavailable")
    }

    private static func lookupCatalogSongs(_ ids: [String]) async throws -> MusicItemCollection<Song> {
        let request: MusicCatalogResourceRequest<Song>
        if ids.count == 1, let id = ids.first {
            request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        } else {
            request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids.map { MusicItemID($0) })
        }
        do {
            return try await request.response().items
        } catch let error as MusicDataRequest.Error where error.status == 404 {
            throw MusicError.songUnavailable
        }
    }

    // MARK: - Error Types

    enum MusicError: LocalizedError {
        case songUnavailable
        case songNoLongerSaved
        case notAuthorized
        case noTracksAvailable
        case playlistCreationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .songUnavailable: "Song unavailable"
            case .songNoLongerSaved: "This saved song could not be found. Close it and try again."
            default: nil
            }
        }
    }
}
