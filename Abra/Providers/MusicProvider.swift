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
    
    private(set) var nowPlaying: String?
    private(set) var lastPlayed: String?
    private(set) var errorMessage: String?
    
    init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
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
            nowPlaying = musicPlayer.playbackState == .playing ? musicPlayer.nowPlayingItem?.playbackStoreID : nil
            lastPlayed = musicPlayer.nowPlayingItem?.playbackStoreID
        }
    }
    
    /// Play/pause according to whether ID is currently being played
    func playPause(id: String) {
        playPause(ids: [id])
    }
    
    /// Play/pause according to whether IDs are currently being played
    func playPause(ids: [String]) {
        if let now = nowPlaying {
            if !ids.contains(now) {
                Task {
                    await play(ids: ids)
                }
                    
                return
            }
                
            stopPlayback()
        } else {
            Task {
                await play(ids: ids)
            }
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
    
    func queue(ids: [String], position: MusicKit.MusicPlayer.Queue.EntryInsertionPosition = .tail) async {
        let musicItemIDs = ids.map { MusicItemID($0) }
        
        do {
            // Fetch Song objects for the given IDs
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: musicItemIDs)
            let response = try await request.response()
            let songs = response.items

            // Insert songs into the queue at position
            try await musicKitPlayer.queue.insert(songs, position: position)
        } catch {
            print("Error inserting songs into queue: \(error)")
        }
    }
    
    func stopPlayback() {
        musicPlayer.pause()
    }
    
    func authorize() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status != .authorized {
            Task { @MainActor in
                errorMessage = "Music playback is not authorized."
            }
        }
    }
    
    /// Fetches track information from Apple Music using the track ID
    /// - Parameter trackId: The Apple Music ID for the track
    /// - Returns: MusicItemCollection<Song> Element with a bunch of metadata
    @discardableResult
    func fetchTrackInfo(_ trackId: String) async throws -> MusicItemCollection<Song>.Element? {
        do {
            if authorizationStatus == .notDetermined {
                await authorize()
            }
            
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(rawValue: trackId))
            let response = try await request.response()
            
            if let song = response.items.first {
                return song
            } else {
                print("No song found for track ID: \(trackId)")
                return nil
            }
        } catch {
            print("Error fetching track info: \(error)")
            throw error
        }
    }
    
    /// Creates a playlist in Apple Music from a collection of ShazamStreams and returns the link to the playlist
    /// - Parameters:
    ///   - streams: Collection of ShazamStreams to add to the playlist
    ///   - name: Name for the playlist
    ///   - description: Optional description for the playlist
    /// - Returns: persistentID of the created playlist
    func createPlaylist(from streams: [ShazamStream], name: String, description: String? = nil) async throws -> MPMediaEntityPersistentID {
        // Ensure user has authorized access to Apple Music
        if authorizationStatus != .authorized {
            await authorize()
            guard authorizationStatus == .authorized else {
                throw MusicError.notAuthorized
            }
        }
            
        // Extract track IDs from ShazamStreams
        let trackIDs = streams.compactMap { $0.appleMusicID }
        guard !trackIDs.isEmpty else {
            throw MusicError.noTracksAvailable
        }
            
        // Create a new playlist
        do {
            let creationMetadata = MPMediaPlaylistCreationMetadata(name: name)
            creationMetadata.descriptionText = description ?? ""

            let playlist = try await MPMediaLibrary.default().getPlaylist(with: UUID(), creationMetadata: creationMetadata)

            // Sometime in the future, it may be optimal to fetch MPMediaItem(s) and use .add() instead
            for id in trackIDs {
                try await playlist.addItem(withProductID: id)
            }
            
            return playlist.persistentID
        } catch {
            Task { @MainActor in
                self.errorMessage = "Failed to create playlist: \(error.localizedDescription)"
            }
            throw MusicError.playlistCreationFailed(error)
        }
    }
    
    enum MusicError: Error {
        case notAuthorized
        case noTracksAvailable
        case playlistCreationFailed(Error)
    }
}
