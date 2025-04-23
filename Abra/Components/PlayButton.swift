//
//  PlayButton.swift
//  Abra
//

import MusicKit
import SwiftUI

struct PlayButton: View {
    @Environment(\.openURL) private var openURL
    
    @State private var music = MusicService()
    @State private var alertShown = false
    
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
        .alert(music.errorMessage ?? "Something went wrong.", isPresented: $alertShown) {
            // If it's a permissions issue, include a handy button to jump right there!
            if (music.errorMessage != nil) && music.errorMessage!.contains("Not authorized") {
                Button("Grant Access") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            
            Button("Close", role: .cancel) {}
        }
    }
    
    private func button() {
        if music.errorMessage != nil {
            return alertShown = true
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
