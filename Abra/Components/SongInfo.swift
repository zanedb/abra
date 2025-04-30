//
//  SongInfo.swift
//  Abra
//

import SwiftUI

struct SongInfo: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var loadedMetadata: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Divider()
            
            HStack(alignment: .center) {
                stat(
                    "From",
                    Button(action: openAppleMusic) {
                        Image(systemName: "arrow.up.right.square")
                        Text(albumTitle)
                            .lineLimit(1)
                            .redacted(reason: loadedMetadata ? [] : .placeholder)
                            .padding(.leading, -5)
                    }
                    .disabled(stream.appleMusicURL == nil)
                    .accessibilityLabel("Open album in Music")
                )
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 6)
                
                stat(
                    "Released",
    
                    Text(released)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                )
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 6)
                
                stat(
                    "Discovered",
                    
                    Text("While \(stream.modality)")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .redacted(reason: .placeholder)
                )
            }
            .padding(.bottom, 4)
            .padding(.top, 2)
            
            Divider()
        }
        .padding(.top)
        .onAppear(perform: getMusicMetadata)
    }
    
    private func stat(_ label: String, _ value: some View) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label)
                    .font(Font.system(.body).smallCaps())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                value
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func openAppleMusic() {
        if let url = stream.appleMusicURL {
            openURL(url)
        }
    }
    
    private func getMusicMetadata() {
        if let id = stream.appleMusicID {
            Task {
                do {
                    let song = try await music.fetchTrackInfo(id)
                    
                    if let albumName = song?.albumTitle, let releaseDate = song?.releaseDate?.year {
                        // Trim "Single" declaration
                        albumTitle = albumName.replacingOccurrences(of: " - Single", with: "")
                        released = releaseDate
                        
                        loadedMetadata = true
                    }
                } catch {
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
        }
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongInfo(stream: .preview)
            .padding()
            .environment(MusicProvider())
    }
}
