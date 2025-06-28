//
//  PlayButton.swift
//  Abra
//

import MusicKit
import SwiftUI

struct PlayButton: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music
    
    var appleMusicID: String
    
    var body: some View {
        Menu {
            Button("Play Next", systemImage: "text.insert", action: playNext)
            Button("Play Later", systemImage: "text.append", action: playLater)
        } label: {
            if (music.currentTrackID == appleMusicID) && music.isPlaying {
                Label("Pause", systemImage: "pause.fill")
            } else {
                Label("Play", systemImage: "play.fill")
            }
        } primaryAction: {
            playPause()
        }
    }
    
    private func playPause() {
        if music.errorMessage != nil {
            return unauthorized()
        }
        
        if music.isPlaying {
            // If the PlayButton is on a different SongView, start new playback
            if music.currentTrackID != appleMusicID {
                Task {
                    await music.play(id: appleMusicID)
                }
                
                return
            }
            
            music.stopPlayback()
        } else {
            Task {
                await music.play(id: appleMusicID)
            }
        }
    }
    
    private func playNext() {
        if music.errorMessage != nil {
            return unauthorized()
        }
        
        // So here's the thing, I can't control the queue with
        // MPMusicPlayerController.systemMusicPlayer
        
        // I'd have to create a custom controller using
        // MPMusicPlayerApplicationController, and I don't love the experience of that
        
        // At the same time it may be necessary to create "stations"
        
        toast.show(
            message: "Not yet!",
            type: .info,
            symbol: "hand.raised"
        )
    }
    
    private func playLater() {
        if music.errorMessage != nil {
            return unauthorized()
        }
        
        toast.show(
            message: "Not yet!",
            type: .info,
            symbol: "hand.raised"
        )
    }
    
    private func unauthorized() {
        toast.show(
            message: "Music unauthorized",
            type: .error,
            symbol: "ear.trianglebadge.exclamationmark",
            action: {
                // On permissions issue, tapping takes you right to app settings!
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
        )
    }
}

#Preview {
    PlayButton(appleMusicID: ShazamStream.preview.appleMusicID ?? "1486262969")
        .environment(MusicProvider())
}
