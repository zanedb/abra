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
    
    var authorizationStatus: MusicAuthorization.Status?
    
    private(set) var isPlaying = false
    private(set) var currentTrackID: String?
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
            isPlaying = musicPlayer.playbackState == .playing
        }
    }
    
    func play(id: String) async {
        await play(ids: [id])
    }
    
    func play(ids: [String]) async {
        if currentTrackID == ids.first {
            // Resume if currently playing song is requested
            musicPlayer.play()
            
            Task { @MainActor in
                isPlaying = true
            }
                
            return
        }
        
        musicPlayer.setQueue(with: ids)
        
        musicPlayer.prepareToPlay { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                    self.isPlaying = false
                }
                return
            }
            
            self.musicPlayer.play()
            Task { @MainActor in
                self.errorMessage = nil
                self.currentTrackID = ids.first
                self.isPlaying = true
            }
        }
    }
    
    func stopPlayback() {
        musicPlayer.pause()
        Task { @MainActor in
            isPlaying = false
        }
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
    /// - Returns: URL to the created playlist, or nil if creation fails
    func createPlaylist(from streams: [ShazamStream], name: String, description: String? = nil) async throws -> URL? {
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

            for id in trackIDs {
                try await playlist.addItem(withProductID: id)
            }
            
            // Generate and return the URL to the playlist
            return URL(string: "music://playlist/\(playlist.persistentID)")
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
