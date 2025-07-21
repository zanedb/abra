//
//  SongSheet.swift
//  Abra
//

import Kingfisher
import MusicKit
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
    
    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var genre: String = "Electronic"
    @State private var loadedMetadata: Bool = false
    
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
                    .font(.bigTitle)
                    .padding(.bottom, 2)
                    .lineLimit(2)
                    .frame(maxWidth: mini ? 220 : 180, alignment: .leading)
                Text(stream.artist)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
                    .padding(.bottom, 3)
                    .lineLimit(2)
                    .frame(maxWidth: mini ? 180 : 220, alignment: .leading)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(genre)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 2).bold())
                        .foregroundStyle(.secondary)
                    
                    Text(released)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }
                .opacity(mini ? 0 : 1)
                
                Button(action: openAppleMusic) {
                    Image(systemName: "smallcircle.filled.circle")
                        .padding(.trailing, -5)
                    Text(albumTitle)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }
                .padding(.top, 5)
                .disabled(stream.appleMusicURL == nil)
                .accessibilityLabel("Open album in Music")
                .opacity(mini ? 0 : 1)
            }
            
            Spacer()
        }
        .frame(height: 96)
        .task(id: stream.persistentModelID, loadMetadata)
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
    
    @Sendable private func loadMetadata() async {
        guard let id = stream.appleMusicID else { return loadedMetadata = false }
        
        do {
            let song = try await music.fetchTrackInfo(id)
                
            if let albumName = song?.albumTitle, let releaseDate = song?.releaseDate?.year, let genres = song?.genreNames {
                albumTitle = albumName
                genre = genres.first ?? ""
                released = releaseDate
                    
                loadedMetadata = true
            }
        } catch {
            loadedMetadata = false // Don't show stale information
            
            var message = error.localizedDescription
            if let e = error as? MusicDataRequest.Error {
                message = e.title
            }
            
            toast.show(
                message: message,
                type: .error,
                symbol: "exclamationmark.circle.fill",
                action: {
                    // On permissions issue, tapping takes you right to app settings!
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            )
        }
    }
    
    private func playPause() {
        guard let id = stream.appleMusicID else { return }
        
        if music.errorMessage != nil {
            return toast.show(
                message: "Music unauthorized",
                type: .error,
                symbol: "exclamationmark.circle.fill",
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
    
    private func openAppleMusic() {
        if let url = stream.appleMusicURL {
            openURL(url)
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
