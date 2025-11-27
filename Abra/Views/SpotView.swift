//
//  SpotView.swift
//  Abra
//

import MapKit
import MediaPlayer
import MusicKit
import SwiftUI

struct SpotView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(SheetProvider.self) private var view
    @Environment(MusicProvider.self) private var music

    @Namespace var animation

    @Bindable var spot: Spot

    @State private var showingIconDesigner: Bool = false
    @State private var showingConfirmation: Bool = false
    @State private var showingNewPlaylist = false
    @State private var newPlaylist: Playlist?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                heading
                    .padding(.top, -40)

                Photos(spot: spot)
                    .padding(.top, 8)
                    .foregroundStyle(.gray)

                Text("^[\(spot.streams.count) Song](inflect: true)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline.weight(.medium))
                    .textCase(.uppercase)
                    .padding(.horizontal)
                    .padding(.top, 12)

                List(spot.streams) { stream in
                    SongRowMini(
                        stream: stream,
                        onTapGesture: {
                            if let appleMusicID = stream.appleMusicID {
                                music.playPause(id: appleMusicID)
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .toolbar {
                ToolbarItems
            }
            .popover(isPresented: $showingIconDesigner) {
                IconDesigner(
                    symbol: $spot.symbol,
                    color: $spot.color,
                    animation: animation,
                    id: spot.persistentModelID
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingNewPlaylist) {
                NewPlaylist(
                    initial: spot.streams,
                    playlist: $newPlaylist,
                    showIncludeToggle: false
                )
                .presentationDetents([.large])
            }
            .onChange(of: newPlaylist) {
                if let playlist = newPlaylist {
                    // NOTE: playlist.artwork? is available!
                    showingNewPlaylist = false
                    toast.show(
                        message: "Playlist created",
                        type: .success,
                        symbol: "music.note.list",
                        action: {
                            // Note: this doesn't actually work. I don't think there is a URL scheme for this.
                            openURL(
                                URL(string: "music://playlist/\(playlist.id)")!
                            )
                        }
                    )
                }
            }
            .onDisappear {
                // Destroy Spot if not saved
                // TODO: test if there are cases where this isn't triggered
                // TODO: clear if there are no songs perhaps? and symbol check will change soon..
                if spot.name == "" || spot.symbol == "" {
                    modelContext.delete(spot)
                    try? modelContext.save()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            DismissButton()
        }

        if spot.streams.count > 0 {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    music.playPause(
                        ids: spot.streams.compactMap(\.appleMusicID)
                    )
                } label: {
                    Image(
                        systemName: spot.streams.compactMap(\.appleMusicID)
                            .contains(music.nowPlaying ?? "NIL")
                            ? "pause" : "play"
                    )
                }
                .backportCircleSymbolVariant()
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    showingNewPlaylist.toggle()
                } label: {
                    Image(systemName: "music.note.list")
                }
                .backportCircleSymbolVariant()
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Menu {
                Button(
                    "Delete from Abra",
                    systemImage:
                        "trash.fill",
                    role: .destructive,
                    action: {
                        showingConfirmation = true
                    }
                )

                Divider()

                if /*music.subscribed && */
                spot.streams.count > 0 {
                    Button(
                        "Play Next",
                        systemImage:
                            "text.line.first.and.arrowtriangle.forward",
                        action: {
                            Task {
                                await music.queue(
                                    ids: spot.streams.compactMap(
                                        \.appleMusicID
                                    ),
                                    position: .afterCurrentEntry
                                )
                            }
                        }
                    )
                    Button(
                        "Add to Queue",
                        systemImage: "text.line.last.and.arrowtriangle.forward",
                        action: {
                            Task {
                                await music.queue(
                                    ids: spot.streams.compactMap(
                                        \.appleMusicID
                                    ),
                                    position: .tail
                                )
                            }
                        }
                    )

                    Divider()

                    ControlGroup {
                        Button(
                            spot.streams.compactMap(\.appleMusicID)
                                .contains(music.nowPlaying ?? "NIL")
                                ? "Pause" : "Play",
                            systemImage: spot.streams.compactMap(\.appleMusicID)
                                .contains(music.nowPlaying ?? "NIL")
                                ? "pause.fill" : "play.fill",
                            action: {
                                music.playPause(
                                    ids: spot.streams.compactMap(\.appleMusicID)
                                )
                            }
                        )

                        Button(
                            "Shuffle",
                            systemImage: "shuffle",
                            action: {
                                spot.play(music, shuffle: true)
                            }
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .confirmationDialog(
                "This spot will be deleted from your Abra library, though the contents will not be deleted.",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Spot", role: .destructive, action: remove)
            }
        }
    }

    private var heading: some View {
        HStack {
            Button(action: { showingIconDesigner.toggle() }) {
                SpotIcon(
                    symbol: spot.symbol,
                    color: Color(spot.color),
                    size: 80
                )
                .matchedTransitionSource(id: spot.id, in: animation)
                .padding(.trailing, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                TextField("Name", text: $spot.name)
                    .font(.title)
                    .frame(maxWidth: 180, alignment: .leading)
                    .bold()
                Text(spot.description)
                    .foregroundStyle(.gray)
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func remove() {
        withAnimation {
            modelContext.delete(spot)
            try? modelContext.save()
        }
        dismiss()
    }
}

#Preview {
    @Previewable var spot = Spot(
        name: "Me",
        symbol: "play.fill",
        latitude: ShazamStream.preview.latitude,
        longitude: ShazamStream.preview.longitude,
        shazamStreams: [.preview, .preview]
    )

    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SpotView(spot: spot)
                .environment(SheetProvider())
                .environment(MusicProvider())
                .environment(LibraryProvider())
                .presentationDetents([.fraction(0.50), .fraction(0.999)])
                .presentationBackgroundInteraction(.enabled)
        }
}
