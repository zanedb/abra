//
//  SongInfo.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongInfo: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(SheetProvider.self) private var view
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var loadedMetadata: Bool = false
    
    private var type: SpotType {
        stream.modality == .driving ? .vehicle : .place
    }
    
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
                        .fontWeight(.medium)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                )
                
                column
                
                stat(
                    "Album",
                    Button(action: openAppleMusic) {
                        Image(systemName: "arrow.up.right.square")
                        Text(albumTitle)
                            .lineLimit(1)
                            .fontWeight(.medium)
                            .redacted(reason: loadedMetadata ? [] : .placeholder)
                            .padding(.leading, -5)
                    }
                    .disabled(stream.appleMusicURL == nil)
                    .accessibilityLabel("Open album in Music")
                )
                
                column
                
                stat(
                    "Discovered",
                    Menu {
                        Button(
                            "New \(type == .place ? "Spot" : "Vehicle")",
                            systemImage: "plus",
                            action: { newSpot(type) }
                        )
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
                                ? (type == .place ? "mappin.and.ellipse" : "car.fill")
                                : stream.spot!.iconName
                        )
                        Text(stream.spot == nil ? "Select" : stream.spot!.name)
                            .lineLimit(1)
                            .fontWeight(.medium)
                            .padding(.leading, -3)
                    }
                    .padding(.top, -8)
                )
                .padding(.trailing, 8)
            }
            
            Divider()
        }
        .task(id: stream.persistentModelID) {
            guard let id = stream.appleMusicID else { return }
            
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
                    message: "Music error",
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
    
    private func stat(_ label: String, _ value: some View) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label)
                    .font(.system(size: 15).smallCaps())
                    .foregroundStyle(.secondary)
                    
                value
            }
            .padding(.vertical, 1)
        }
    }
    
    private var column: some View {
        Divider()
            .frame(height: 30)
            .padding(.horizontal, 8)
    }
    
    private func openAppleMusic() {
        if let url = stream.appleMusicURL {
            openURL(url)
        }
    }
    
    private func newSpot(_ type: SpotType) {
        // Dismiss song sheet
        let selected = view.stream
        view.stream = nil
           
        // Create new Spot, insert into modelContext, and open for immediate editing
        // TODO: fetch ShazamStreams by radius and include them here
        let spot = Spot(name: "", type: type, iconName: "", latitude: selected!.latitude, longitude: selected!.longitude, shazamStreams: [selected!])
        modelContext.insert(spot)
        view.spot = spot
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
            .environment(SheetProvider())
            .environment(MusicProvider())
    }
}
