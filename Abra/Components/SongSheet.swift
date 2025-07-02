//
//  SongSheet.swift
//  Abra
//

import Kingfisher
import SwiftUI

struct SongSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) var music
    
    var stream: ShazamStream
    var mini: Bool = false
    
    private var imageSize: CGFloat {
        mini ? 48 : 96
    }
    
    var body: some View {
        HStack(alignment: .top) {
            KFImage(stream.artworkURL)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
                .padding(.leading, mini ? 4 : 0)
                .overlay {
                    if !mini && stream.appleMusicID != nil {
                        playButton
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .font(.system(size: 18))
                    .padding(.bottom, 2)
                    .lineLimit(2)
                    .frame(maxWidth: mini ? 220 : 180, alignment: .leading)
                Text(stream.artist)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .padding(.bottom, 3)
                    .lineLimit(2)
                    .frame(maxWidth: mini ? 180 : 220, alignment: .leading)
                
                Spacer()
            }
            
            Spacer()
        }
        .frame(height: 96)
    }
    
    private var playButton: some View {
        Button(action: playPause) {
            Image(systemName: (music.currentTrackID == stream.appleMusicID) && music.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 40))
                .foregroundStyle(.thickMaterial)
                .shadow(radius: 2)
                .frame(width: imageSize, height: imageSize)
        }
    }
    
    private func playPause() {
        guard let id = stream.appleMusicID else { return }
        
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
            if music.currentTrackID != id {
                Task {
                    await music.play(id: id)
                }
                
                return
            }
            
            music.stopPlayback()
        } else {
            Task {
                await music.play(id: id)
            }
        }
    }
}

#Preview {
    @State @Previewable var preview: ShazamStream = .preview
    
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongSheet(stream: preview)
            .onAppear {
                preview.appleMusicURL = URL(string: "https://music.apple.com/us/album/id1411801429")!
                preview.appleMusicID = "1411801429"
            }
            .environment(MusicProvider())
            .padding()
    }
}
