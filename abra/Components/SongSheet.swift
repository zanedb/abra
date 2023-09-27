//
//  SongSheet.swift
//  abra
//
//  Created by Zane on 6/7/23.
//

import SwiftUI
import SDWebImageSwiftUI

struct SongSheet: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var music = MusicController.shared.music
    
    var stream: ShazamStream
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(spacing: 0) {
                    WebImage(url: stream.artworkURL)
                        .resizable()
                        .placeholder {
                            ProgressView()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .padding(.trailing, 5)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .cornerRadius(3.0)
                        .padding(.trailing, 5)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(stream.title)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                        .font(.system(size: 18))
                        .padding(.bottom, 2)
                    Text(stream.artist)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.60))
                        .font(.system(size: 15))
                        .padding(.bottom, 3)
                    Text(stream.timestamp.formatted(.dateTime.hour().minute()) + ", " + (stream.city ?? "a strange land"))
                        .foregroundColor(Color.gray)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    PlayButton(appleMusicID: stream.appleMusicID ?? "1486262969")
                }
            }
            .frame(height: 96)
            .frame(minWidth: 100, maxWidth: 300)
        }
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongSheet(stream: .preview)
    }
}
