//
//  MusicProvider.swift
//  Abra
//

import Foundation
import MediaPlayer
import MusicKit
import StoreKit

@Observable class MusicProvider {
    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    let musicKitPlayer = SystemMusicPlayer.shared

    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var subscribed: Bool = false

    private(set) var nowPlaying: String?
    private(set) var lastPlayed: String?
    private(set) var errorMessage: String?
    private var previewPlayer: AVPlayer?

    init() {
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
        if lastPlayed == ids.first {
            // Resume if currently playing song is requested
            musicPlayer.play()
            return
        }

        do {
            // Play next, skip one
            await queue(ids: ids, position: .afterCurrentEntry)
            try await musicKitPlayer.skipToNextEntry()

            // Play using MPMusicPlayerController so it reports the event properly
            musicPlayer.play()
        } catch {
            print("Error playing: \(error)")
        }
    }

    func stopPlayback() {
        musicPlayer.pause()
    }

    // MARK: - Queue

    func queue(
        ids: [String],
        position: MusicKit.MusicPlayer.Queue.EntryInsertionPosition = .tail
    ) async {
        let musicItemIDs = ids.map { MusicItemID($0) }

        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                memberOf: musicItemIDs
            )
            let response = try await request.response()
            try await musicKitPlayer.queue.insert(
                response.items,
                position: position
            )
        } catch {
            print("Error inserting songs into queue: \(error)")
        }
    }

    // MARK: - Preview Playback

    /// Use AVPlayer to play the preview for non-subscribers
    func playPreview(for trackId: String) async {
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(rawValue: trackId)
            )
            let response = try await request.response()
            guard let song = response.items.first,
                let previewURL = song.previewAssets?.first?.url
            else {
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

    func authorize() async {
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
        if authorizationStatus == .notDetermined {
            await authorize()
        }
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(rawValue: trackId)
            )
            let response = try await request.response()
            return response.items.first
        } catch {
            print("Error fetching track info: \(error)")
            throw error
        }
    }

    // MARK: - Error Types

    enum MusicError: Error {
        case notAuthorized
        case noTracksAvailable
        case playlistCreationFailed(Error)
    }
}
