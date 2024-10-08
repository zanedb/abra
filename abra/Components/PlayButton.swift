//
//  Play.swift
//  abra
//
//  Created by Zane on 6/19/23.
//

import SwiftUI
import MusicKit

struct PlayButton: View {
    @StateObject var music = MusicController.shared.music
    
    var appleMusicID: String
    
    var body: some View {
        Button(action: { music.play(id: appleMusicID)}) {
            Label("Listen", systemImage: "play.fill")
        }
    }
}

#Preview {
    PlayButton(appleMusicID: ShazamStream.preview.appleMusicID ?? "1486262969")
}
