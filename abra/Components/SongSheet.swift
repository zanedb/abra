//
//  SongSheet.swift
//  abra
//
//  Created by Zane on 6/7/23.
//

import SwiftUI
import MusicKit

struct SongSheet: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var music = MusicController.shared.music
    
    var stream: SStream
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(spacing: 0) {
                    AsyncImage(
                        url: stream.artworkURL,
                        content: { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 148, height: 148)
                                .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                                .padding(.trailing, 5)
                        },
                        placeholder: {
                            ProgressView()
                                .scaledToFit()
                                .frame(width: 148, height: 148)
                                .padding(.trailing, 5)
                        }
                    )
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(stream.trackTitle ?? "Loading…")
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                        .font(.system(size: 20))
                        .padding(.bottom, 3)
                    Text(stream.artist ?? "…")
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.60))
                        .font(.system(size: 17))
                        .padding(.bottom, 3)
                    //                        Text(selectedPlace!.timestamp.formatted(.dateTime.day().month().hour().minute())) // fix
                    //                            .foregroundColor(Color.gray)
                    //                            .font(.system(size: 13))
                    Text((stream.city ?? "…") + ", " + (stream.country ?? "…"))
                        .foregroundColor(Color.gray)
                        .font(.system(size: 15))
                    Spacer()
                    
                    Button(action: { music.play(id: stream.appleMusicID!)}) {
                        Label("Listen", systemImage: "play.fill")
                    }
                    Spacer()
                }
            }
            .frame(height: 148)
        }
    }
}

struct SongSheet_Previews: PreviewProvider {
    static var previews: some View {
        SongSheet(stream: SStream.example)
    }
}
