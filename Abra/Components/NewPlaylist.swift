//
//  NewPlaylist.swift
//  Abra
//

import MediaPlayer
import SwiftUI
import MusadoraKit

struct NewPlaylist: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicProvider.self) private var music

    var initial: [ShazamStream] = []
    @Binding var playlist: Playlist?
    var showIncludeToggle: Bool

    @State var title: String = ""
    @State var loading = false
    @State var includingSpotStreams = false

    private var spotStreams: [ShazamStream] {
        initial.first?.spot?.shazamStreams ?? initial
    }

    private var streams: [ShazamStream] {
        includingSpotStreams ? spotStreams : initial
    }

    init(
        initial: [ShazamStream],
        playlist: Binding<Playlist?> = .constant(nil),
        showIncludeToggle: Bool = true
    ) {
        self.initial = initial
        self._playlist = playlist
        self.showIncludeToggle = showIncludeToggle
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

                if showIncludeToggle {
                    Toggle(isOn: $includingSpotStreams) {
                        Text(
                            "Add Songs from \(streams.first?.spot?.name ?? "Spot")"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }

                List(streams) { stream in
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
                let musicItemIDs: [MusicItemID] = trackIDs.compactMap { MusicItemID($0) }
                playlist = try await MLibrary.createPlaylist(with: title, songIds: musicItemIDs)
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
                initial: initial.shazamStreams ?? [],
                playlist: .constant(nil)
            )
            .environment(SheetProvider())
            .environment(ShazamProvider())
            .environment(MusicProvider())
            .modelContainer(PreviewSampleData.container)
        }
}
