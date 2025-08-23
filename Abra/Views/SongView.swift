//
//  SongView.swift
//  Abra
//

import MusicKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var genre: String = "Electronic"
    @State private var loadedMetadata: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Info
                    .padding()
                    .padding(.top, -26)
                
                SongDiscovered(stream: stream)
                    
                Photos(stream: stream)
                
                SongActions(stream: stream)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(stream.title)
                        .font(.title2.weight(.bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: -4) {
                        if let appleMusicID = stream.appleMusicID {
                            Menu {
                                Button("Add to Queue", systemImage: "text.line.last.and.arrowtriangle.forward", action: {
                                    Task {
                                        await music.queue(ids: [appleMusicID], position: .tail)
                                    }
                                })
                                Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward", action: {
                                    Task {
                                        await music.queue(ids: [appleMusicID], position: .afterCurrentEntry)
                                    }
                                })
                                if let url = stream.appleMusicURL {
                                    Divider()
                                    ShareLink("Share Album", item: url)
                                }
                            } label: {
                                Image(systemName: music.nowPlaying == appleMusicID ? "pause.circle.fill" : "play.circle.fill")
                                    .foregroundStyle(.gray)
                                    .font(.button)
                                    .symbolRenderingMode(.hierarchical)
                            } primaryAction: {
                            }
                        }
                        DismissButton()
                    }
                }
            }
        }
    }
    
    var Info: some View {
        HStack(spacing: 4) {
            Text(stream.artist)
                .foregroundStyle(.secondary)
                .font(.headline.weight(.regular))
                .lineLimit(1)
                
            Image(systemName: "circle.fill")
                .font(.system(size: 2).bold())
                .foregroundStyle(.secondary)
            
            Button(action: {
                if let url = stream.appleMusicURL {
                    openURL(url)
                }
            }) {
                Text(albumTitle)
                    .font(.headline.weight(.regular))
                    .lineLimit(1)
                    .redacted(reason: loadedMetadata ? [] : .placeholder)
            }
            .disabled(stream.appleMusicURL == nil)
            .accessibilityLabel("Open album in Music")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: stream.persistentModelID, loadMetadata)
    }
    
    @Sendable private func loadMetadata() async {
        guard let id = stream.appleMusicID else { return loadedMetadata = false }
        
        do {
            let song = try await music.fetchTrackInfo(id)
                
            if let albumName = song?.albumTitle, let releaseDate = song?.releaseDate?.year, let genres = song?.genreNames {
                albumTitle = albumName.hasSuffix(" - Single") ? "Single" : albumName
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
                action: message == "Permission denied" ? {
                    // On permissions issue, tapping takes you right to app settings!
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                } : nil
            )
        }
    }
}

#Preview {
    EmptyView()
        .inspector(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
