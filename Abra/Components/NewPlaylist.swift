//
//  NewPlaylist.swift
//  Abra
//

import SwiftUI
import MediaPlayer

struct NewPlaylist: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicProvider.self) private var music
    
    init(initial: ShazamStream, playlistID: Binding<MPMediaEntityPersistentID?>) {
        _streams = .init(wrappedValue: [initial])
        _playlistID = playlistID
        initializedFromStream = true
    }
    
    init(initial: Spot, playlistID: Binding<MPMediaEntityPersistentID?>) {
        _streams = .init(wrappedValue: initial.shazamStreams ?? [])
        _playlistID = playlistID
        initializedFromStream = false
    }
    
    private var initializedFromStream: Bool
    private var allSpotStreams: [ShazamStream] {
        initializedFromStream ? streams.first?.spot?.shazamStreams ?? streams : []
    }
    
    @Binding var playlistID: MPMediaEntityPersistentID?
    
    @State var title: String = ""
    @State var includingSpotStreams = false
    @State var streams: [ShazamStream] = []
    @State var loading = false
    
    var actualStreams: [ShazamStream] {
        includingSpotStreams ? allSpotStreams : streams
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                PlaylistImage
                
                TextField("Playlist Title", text: $title)
                    .font(.bigTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                
                Divider()
                    .padding(.horizontal)
                
                if initializedFromStream {
                    Toggle("Include All Songs from \(streams.first?.spot?.name ?? "Spot")", isOn: $includingSpotStreams)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                
                List(actualStreams) { stream in
                    SongRowMini(stream: stream)
                }
                .listStyle(.inset)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !loading {
                        Button("Create", action: createPlaylist)
                            .disabled(title.isEmpty)
                            .fontWeight(.medium)
                    } else {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
    }
    
    private var PlaylistImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.indigo)
            .frame(width: 176, height: 176)
            .padding()
    }
    
    private func createPlaylist() {
        loading = true
        Task {
            do {
                playlistID = try await music.createPlaylist(from: actualStreams, name: title)
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    @Previewable @State var initial: ShazamStream = .preview
//    @Previewable @State var initial: Spot = .preview
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            NewPlaylist(initial: initial, playlistID: .constant(nil))
                .environment(SheetProvider())
                .environment(MusicProvider())
                .modelContainer(PreviewSampleData.container)
        }
}
