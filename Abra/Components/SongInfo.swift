//
//  SongInfo.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongInfo: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var loadedMetadata: Bool = false
    
    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]
    
    var body: some View {
        VStack(alignment: .leading) {
            Divider()
            
            HStack {
                stat(
                    "Released",
    
                    Text(released)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                )
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                
                stat(
                    "Album",
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
                    .padding(.horizontal, 8)
                
                stat(
                    "Discovered",
                    Menu {
                        Button("New \(stream.modality == .driving ? "Vehicle" : "Spot")", systemImage: "plus", action: {})
                        Divider()
                        
                        ForEach(spots) { spot in
                            Button(
                                spot.name,
                                systemImage: spot.iconName,
                                action: { addToSpot(spot) }
                            )
                        }
                    } label: {
                        Image(
                            systemName: stream.spot == nil
                                ? (stream.modality == .driving ? "car.fill" : "mappin.circle")
                                : stream.spot!.iconName
                        )
                        Text(stream.spot == nil ? "Select" : stream.spot!.name)
                            .lineLimit(1)
                            .padding(.leading, -3)
                    }
                    .padding(.top, -8)
                )
                .padding(.trailing, 8)
            }
            
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
        }
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
    
    private func addToSpot(_ spot: Spot) {
        // TODO: ensure it can't be applied to multiple, clicking again removes, etc
        // Replace Menu with Picker?
        stream.spot = spot
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongInfo(stream: .preview)
            .padding()
            .environment(MusicProvider())
    }
}
