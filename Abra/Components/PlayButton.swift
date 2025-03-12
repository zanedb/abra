//
//  PlayButton.swift
//  Abra
//

import SwiftUI
import MusicKit

struct PlayButton: View {
    @Environment(\.openURL) private var openURL
    @StateObject var music = MusicController.shared.music
    @State private var alertShown = false
    
    var appleMusicID: String
    
    var body: some View {
        Button(action: {
            if music.errorMessage != nil {
                return alertShown = true
            }
            
            if music.isPlaying {
                music.stopPlayback()
                
                // If the PlayButton is on a different SongView, start new playback
                if music.currentTrackID != appleMusicID {
                    music.play(id: appleMusicID)
                }
            } else {
                music.play(id: appleMusicID)
            }
        }) {
            if (music.currentTrackID == appleMusicID) && music.isPlaying {
                Label("Pause", systemImage: "pause.fill")
            } else {
                Label("Play", systemImage: "play.fill")
            }
        }
            .onAppear {
                Task {
                    let status = await music.authorize()
                    if status != .authorized {
                        DispatchQueue.main.async {
                            music.errorMessage = "Not authorized to access Apple Music"
                        }
                    }
                }
            }
            .alert(music.errorMessage ?? "Something went wrong.", isPresented: $alertShown) {
                // If it's a permissions issue, include a handy button to jump right there!
                if (music.errorMessage != nil) && music.errorMessage!.contains("Not authorized") {
                    Button("Grant Access") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
                
                Button("Close", role: .cancel) { }
            }
    }
}

#Preview {
    PlayButton(appleMusicID: ShazamStream.preview.appleMusicID ?? "1486262969")
}
