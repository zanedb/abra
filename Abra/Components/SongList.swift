//
//  SongList.swift
//  Abra
//

import MapKit
import SwiftUI

struct SongList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music

    @State var streams: [ShazamStream]
    @Binding var selection: ShazamStream?

    @State private var configuringPlaylist: Bool = false
    @State private var playlistTitle: String = ""
    @State private var playlistDesc: String = ""

    init(group: ShazamStreamGroup, selection: Binding<ShazamStream?>) {
        self.streams = group.wrapped
        self._selection = selection
    }

    var body: some View {
        NavigationStack {
            VStack {
                EditableList($streams) { $stream in
                    Button(action: { selection = stream }) {
                        SongRowMini(stream: stream)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("\(streams.count) Shazam\(streams.count != 1 ? "s" : "") Selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbar
                }
            }
            .alert("Playlist Title", isPresented: $configuringPlaylist) {
                TextField("Bangerz", text: $playlistTitle)
                Button("Create", action: createNewPlaylist)
                Button("Cancel", role: .cancel, action: configurePlaylist)
            } message: {
                Text("[This UI is temporary.]")
            }
            .onChange(of: streams) {
                if streams.count == 0 {
                    dismiss()
                }
            }
        }
    }

    private var toolbar: some View {
        Menu {
            Button(action: configurePlaylist) {
                Label("New Playlist", systemImage: "music.note.list")
                Text("Create a new playlist from these Shazams.")
            }

            Button(action: addToPlaylist) {
                Label("Add to Playlist", systemImage: "list.bullet.indent")
                Text("Add Shazams to an existing playlist.")
            }
        } label: {
            Label("Create", systemImage: "plus")
        }
    }

    private func configurePlaylist() {
        configuringPlaylist.toggle()
    }

    private func createNewPlaylist() {
        Task {
            do {
                let playlistURL = try await music.createPlaylist(
                    from: streams,
                    name: playlistTitle,
                    description: playlistDesc
                )

                if let url = playlistURL {
                    openURL(url)
                }
            } catch {
                // Handle errors
                print("Failed to create playlist: \(error)")
            }
        }
    }

    private func addToPlaylist() {
        toast.show(message: "Ha! Not yet ;)", type: .warning)
    }
}

#Preview {
    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SongList(group: ShazamStreamGroup(wrapped: [.preview, .preview]), selection: .constant(nil))
                .environment(MusicProvider())
                .presentationDetents([.fraction(0.50), .large])
                .presentationBackgroundInteraction(.enabled)
        }
}
