//
//  SongView.swift
//  Abra
//

import MusicKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(MusicProvider.self) private var music
    @Environment(ShazamProvider.self) private var shazam

    var stream: ShazamStream

    @State private var showingConfirmation = false
    @State private var showingPlaylistPicker = false
    @State private var showingLocationPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {

                SongInfo(stream: stream)

                SongDiscovered(stream: stream)

                Photos(stream: stream)
            }
            .toolbar {
                ToolbarItems
            }
            .popover(isPresented: $showingPlaylistPicker) {
                PlaylistPicker(stream: stream)
                    .presentationDetents([.large])
            }
            .popover(isPresented: $showingLocationPicker) {
                LocationPicker(stream: stream)
                    .presentationDetents([.large])
            }
            .confirmationDialog(
                "This song will be deleted from your Abra and Shazam libraries.",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Song", role: .destructive, action: remove)
            }
        }
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            DismissButton()
        }

        if let url = stream.appleMusicURL {
            ToolbarItem(placement: .topBarLeading) {
                ShareLink("Music", item: url)
            }
        }

        if let appleMusicID = stream.appleMusicID {
            ToolbarItem(placement: .bottomBar) {
                Button(action: { music.playPause(id: appleMusicID) }) {
                    Image(
                        systemName: music.nowPlaying == appleMusicID
                            ? "pause" : "play"
                    )
                }
                .backportCircleSymbolVariant()
            }

            ToolbarItem(placement: .bottomBar) {
                Button(
                    "Add to Playlist",
                    systemImage:
                        "music.note.list",
                    action: {
                        showingPlaylistPicker.toggle()
                    }
                )
                .backportCircleSymbolVariant()
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Menu {
                if music.subscribed, let appleMusicID = stream.appleMusicID {
                    Button(
                        "Add to Queue",
                        systemImage:
                            "text.line.last.and.arrowtriangle.forward",
                        action: {
                            Task {
                                await music.queue(
                                    ids: [appleMusicID],
                                    position: .tail
                                )
                            }
                        }
                    )
                    Button(
                        "Play Next",
                        systemImage:
                            "text.line.first.and.arrowtriangle.forward",
                        action: {
                            Task {
                                await music.queue(
                                    ids: [appleMusicID],
                                    position: .afterCurrentEntry
                                )
                            }
                        }
                    )
                }

                if let link = stream.songLink {
                    Divider()
                    ShareLink("Song.link", item: link)
                }

                if let url = stream.appleMusicURL {
                    ShareLink("Music", item: url)
                }

                if stream.latitude == -1 && stream.longitude == -1 {
                    Divider()
                    Button(
                        "Add Location",
                        systemImage:
                            "location.fill.viewfinder",
                        action: {
                            showingLocationPicker.toggle()
                        }
                    )
                }

                Divider()

                Button(
                    "Delete",
                    systemImage:
                        "trash.fill",
                    role: .destructive,
                    action: {
                        showingConfirmation = true
                    }
                )
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    private func remove() {
        withAnimation {
            modelContext.delete(stream)
            try? modelContext.save()
        }
        Task {
            try? await shazam.removeFromLibrary(stream: stream)
        }
        dismiss()
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
