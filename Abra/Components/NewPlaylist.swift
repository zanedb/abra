//
//  NewPlaylist.swift
//  Abra
//

import MediaPlayer
import SwiftUI

struct NewPlaylist: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicProvider.self) private var music
    
    var initial: [ShazamStream] = []
    @Binding var playlistID: MPMediaEntityPersistentID?
    
    @State var title: String = ""
    @State var loading = false
    @State var includingSpotStreams = false
    
    private var spotStreams: [ShazamStream] {
        initial.first?.spot?.shazamStreams ?? initial
    }

    private var streams: [ShazamStream] {
        includingSpotStreams ? spotStreams : initial
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
                
                Toggle(isOn: $includingSpotStreams) {
                    Text("Include All Songs from \(streams.first?.spot?.name ?? "Spot")")
                        .font(.subheading.weight(.regular))
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                List(streams) { stream in
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
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.foreground)
            
            Text(title.isEmpty ? "Playlist Title" : title)
                .foregroundStyle(.background)
                .font(.bigTitle)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 176, height: 176)
        .padding()
    }
    
    private func createPlaylist() {
        loading = true
        Task {
            do {
                playlistID = try await music.createPlaylist(from: streams, name: title)
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    @Previewable @State var initial: Spot = .preview
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            NewPlaylist(initial: initial.shazamStreams ?? [], playlistID: .constant(nil))
                .environment(SheetProvider())
                .environment(MusicProvider())
                .modelContainer(PreviewSampleData.container)
        }
}
