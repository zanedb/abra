//
//  Music.swift
//  Abra
//

import Foundation
import MediaPlayer
import MusicKit
import StoreKit

@Observable class MusicService {
    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    
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
        if currentTrackID == id {
            // Resume if currently playing song is requested
            musicPlayer.play()
            
            Task { @MainActor in
                isPlaying = true
            }
                
            return
        }
        
        musicPlayer.setQueue(with: [id])
        
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
                self.currentTrackID = id
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
        if status != .authorized {
            Task { @MainActor in
                errorMessage = "Music playback is not authorized."
            }
        }
    }
}
