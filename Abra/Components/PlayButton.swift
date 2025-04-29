//
//  PlayButton.swift
//  Abra
//

import MusicKit
import SwiftUI

struct PlayButton: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    
    @State private var music = MusicService()
    
    var appleMusicID: String
    
    var body: some View {
        Button(action: button) {
            if (music.currentTrackID == appleMusicID) && music.isPlaying {
                Label("Pause", systemImage: "pause.fill")
            } else {
                Label("Play", systemImage: "play.fill")
            }
        }
        .task {
            await music.authorize()
        }
    }
    
    private func button() {
        if music.errorMessage != nil {
            return toast.show(
                message: "Music unauthorized",
                type: .error,
                symbol: "ear.trianglebadge.exclamationmark",
                action: {
                    // On permissions issue, tapping takes you right to app settings!
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            )
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
}

#Preview {
    PlayButton(appleMusicID: ShazamStream.preview.appleMusicID ?? "1486262969")
}
