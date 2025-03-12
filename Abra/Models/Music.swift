//
//  Music.swift
//  Abra
//

import Foundation
import MusicKit
import StoreKit
import MediaPlayer

class Music: NSObject, ObservableObject {
    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    
    @Published var isPlaying = false
    @Published var currentTrackID: String?
    @Published var errorMessage: String?
    
    override init() {
        super.init()
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isPlaying = self.musicPlayer.playbackState == .playing
        }
    }
    
    func play(id: String) {
        if currentTrackID == id {
            // Resume if currently playing song is requested
            musicPlayer.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
            return
        }
        
        errorMessage = nil
        currentTrackID = id
        
        musicPlayer.setQueue(with: [id])
        
        musicPlayer.prepareToPlay { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isPlaying = false
                }
                return
            }
            
            self.musicPlayer.play()
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        }
    }
    
    func stopPlayback() {
        musicPlayer.pause()
        isPlaying = false
    }
    
    func authorize() async -> MusicAuthorization.Status {
        return await MusicAuthorization.request()
    }
}

struct MusicController {
    static let shared = MusicController()
    let music = Music()
}
