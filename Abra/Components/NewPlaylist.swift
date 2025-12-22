//
//  NewPlaylist.swift
//  Abra
//

import MediaPlayer
import MusadoraKit
import SwiftUI

struct NewPlaylist: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicProvider.self) private var music

    @Binding var playlist: Playlist?
    var spot: Spot?

    @State var title: String = ""
    @State var loading = false
    @State var includingSpotStreams = false

    @State var streams: [ShazamStream]

    init(
        initial: [ShazamStream],
        playlist: Binding<Playlist?> = .constant(nil),
        showAppendSpotStreams: Bool = false
    ) {
        self.streams = initial
        self._playlist = playlist

        if showAppendSpotStreams {
            self.spot = initial.first?.spot
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                PlaylistImage

                TextField("Playlist Title", text: $title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                Divider()
                    .padding(.horizontal)

                List {
                    ForEach(streams) { stream in
                        SongRowMini(
                            stream: stream,
                            onTapGesture: {
                                if let appleMusicID = stream.appleMusicID {
                                    music.playPause(id: appleMusicID)
                                }
                            }
                        )
                        .padding(.vertical, -4)
                    }
                    .onMove { indexSet, offset in
                        streams.move(fromOffsets: indexSet, toOffset: offset)
                    }
                    .onDelete { indexSet in
                        streams.remove(atOffsets: indexSet)
                    }

                    if let s = spot, !includingSpotStreams {
                        Button {
                            // Don't double dip
                            let addtl = s.streams.filter {
                                $0.persistentModelID
                                    != streams.first?.persistentModelID
                            }
                            includingSpotStreams = true
                            self.streams += addtl
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 48, height: 48)
                                    .clipShape(.rect(cornerRadius: 8))
                                    .padding(.trailing, 5)
                                Text("Add All From \(s.name)")
                            }
                            .padding(.vertical, -4)
                        }
                    }
                }
                .listStyle(.inset)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItems
            }
        }
    }

    @ToolbarContentBuilder
    fileprivate var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !loading {
                Button("Create", action: createPlaylist)
                    .disabled(title.isEmpty)
                    .fontWeight(.medium)
            } else {
                ProgressView()
            }
        }

        ToolbarItem(placement: .topBarLeading) {
            EditButton()
        }
    }

    private var PlaylistImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.foreground)

            Text(title.isEmpty ? "Playlist Title" : title)
                .foregroundStyle(.background)
                .font(.headline)
                .padding(20)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
        .frame(width: 176, height: 176)
        .padding()
    }

    private func createPlaylist() {
        loading = true
        Task {
            do {
                let trackIDs = streams.compactMap { $0.appleMusicID }
                let musicItemIDs: [MusicItemID] = trackIDs.compactMap {
                    MusicItemID($0)
                }
                playlist = try await MLibrary.createPlaylist(
                    with: title,
                    songIds: musicItemIDs
                )
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
            NewPlaylist(
                initial: initial.streams,
                playlist: .constant(nil),
                showAppendSpotStreams: true
            )
            .environment(SheetProvider())
            .environment(ShazamProvider())
            .environment(MusicProvider())
            .modelContainer(PreviewSampleData.container)
        }
}
