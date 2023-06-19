//
//  Music.swift
//  abra
//
//  Created by Zane on 6/7/23.
//

import Foundation
import MusicKit
import MediaPlayer

class Music: NSObject, ObservableObject {
    let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    
    func play(id: String) {
        musicPlayer.setQueue(with: [id])
        musicPlayer.play()
    }
    
    func authorize() async -> MusicAuthorization.Status {
        let res = await MusicAuthorization.request()
        return res
    }
}

struct MusicController {
    static let shared = MusicController()
    
    let music = Music()
}
