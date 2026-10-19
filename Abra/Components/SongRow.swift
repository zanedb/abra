//
//  SongRow.swift
//  Abra
//

import Kingfisher
import SwiftData
import SwiftUI

struct SongRow: View {
    @Environment(\.toastProvider) private var toast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(SheetProvider.self) var view
    @Environment(ShazamProvider.self) private var shazam
    @Environment(MusicProvider.self) private var music

    var stream: ShazamStream

    @State private var confirmationShown = false

    private var nowPlaying: Bool { music.nowPlaying == stream.appleMusicID }

    var body: some View {
        HStack {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 18))
                .padding(.trailing, 5)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(stream.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(stream.relativeDateTime)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 3)

                Text(stream.artist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 3)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    if let spot = stream.spot {
                        HStack(spacing: 4) {
                            Image(systemName: spot.symbol)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(Color(spot.color))
                            Text(spot.name)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }

                    Text(stream.cityState)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        }
        .frame(minHeight: 96)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            if let appleMusicURL = stream.appleMusicURL,
                let appleMusicID = stream.appleMusicID
            {

                
                if let spot = stream.spot {
                    Button(
                        "Show in Spot",
                        systemImage: "mappin",
                        action: { view.show(spot) }
                    )
                    Divider()
                }
                
                
                    ControlGroup {
                        Button(
                            nowPlaying ? "Pause" : "Play",
                            systemImage: nowPlaying ? "pause.fill" : "play.fill",
                            action: { music.playPause(id: appleMusicID) }
                        )
                        
                        Link(destination: appleMusicURL) {
                            Label(
                                "Open in Music",
                                systemImage: "arrow.up.forward"
                            )
                        }

                        
                            ShareLink(item: appleMusicURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                    }
                
                Divider()
                
                Button(
                    "Play Next",
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    action: playNext
                )

                Button(
                        "Add to Queue",
                        systemImage:
                            "text.line.last.and.arrowtriangle.forward",
                        action: addToQueue
                    )
                
                Divider()
            }

            Button(
                "Delete from Abra",
                systemImage: "trash",
                role: .destructive,
                action: { confirmationShown = true }
            )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if stream.appleMusicID != nil {
                Button(
                    "Add to Queue",
                    systemImage: "text.line.last.and.arrowtriangle.forward",
                    action: addToQueue
                )
                .labelStyle(.iconOnly)
                .tint(.orange)

                Button(
                    "Play Next",
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    action: playNext
                )
                .labelStyle(.iconOnly)
                .tint(.indigo)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                confirmationShown = true
            }
            .labelStyle(.iconOnly)

            if let appleMusicURL = stream.appleMusicURL {
                ShareLink(item: appleMusicURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .symbolVariant(.none)
                }
                .labelStyle(.iconOnly)
                .tint(.blue)
            }
        }
        .confirmationDialog(
            "This song will be deleted from your Abra and Shazam libraries.",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("Delete Song", role: .destructive, action: deleteStream)
        }
    }

    private func playNext() {
        guard let appleMusicID = stream.appleMusicID else { return }
        Task {
            if await music.queue(ids: [appleMusicID], position: .afterCurrentEntry) {
                toast.show(message: "Playing Next", type: .success, symbol: "text.line.first.and.arrowtriangle.forward")
            }
        }
    }

    private func addToQueue() {
        guard let appleMusicID = stream.appleMusicID else { return }
        Task {
            if await music.queue(ids: [appleMusicID], position: .tail) {
                toast.show(message: "Added to Queue", type: .success, symbol: "text.line.last.and.arrowtriangle.forward")
            }
        }
    }

    private func deleteStream() {
        withAnimation {
            modelContext.delete(stream)
            try? modelContext.save()
        }
        Task {
            try? await shazam.removeFromLibrary(stream: stream)
        }
    }
}

struct SongRowMini: View {
    static let artworkSize: CGFloat = 48
    static let artworkSpacing: CGFloat = 13
    private static let artworkCornerRadius: CGFloat = 8

    @Environment(SheetProvider.self) var view
    @Environment(MusicProvider.self) private var music
    @Environment(ShazamProvider.self) private var shazam

    var stream: ShazamStream
    var onTapGesture: () -> Void = {}

    private var nowPlaying: Bool {
        music.nowPlaying != nil && music.nowPlaying == stream.appleMusicID
    }
    private var lastPlayed: Bool {
        music.lastPlayed != nil && music.lastPlayed == stream.appleMusicID
    }

    var body: some View {
        HStack(spacing: Self.artworkSpacing) {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .clipShape(.rect(cornerRadius: Self.artworkCornerRadius))
                .overlay {
                    if nowPlaying || lastPlayed {
                        Waveform(on: nowPlaying)
                            .foregroundStyle(.white)
                            .frame(width: Self.artworkSize, height: Self.artworkSize)
                            .background(.black.opacity(0.4))
                            .clipShape(.rect(cornerRadius: Self.artworkCornerRadius))
                            .transition(
                                .opacity.animation(.easeInOut(duration: 0.25))
                            )
                    }
                }

            VStack(alignment: .leading) {
                HStack {
                    Text(stream.title)
                        .lineLimit(1)
                    if stream.isExplicit {
                        Image(systemName: "e.square.fill")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .padding(.leading, -3.0)
                            .accessibilityLabel("Explicit")
                    }
                }

                Text(stream.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapGesture()
        }
        .contextMenu {
            if let appleMusicURL = stream.appleMusicURL {
                Link(destination: appleMusicURL) {
                    Label(
                        "Open in Music",
                        systemImage: "arrow.up.forward"
                    )
                }
                Divider()
                ShareLink(item: appleMusicURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                //                Divider()
            }

            //            Button(
            //                "View",
            //                systemImage: "arrow.up.right",
            //                action: { view.show(stream) }
            //            )
        } preview: {
            SongRow(stream: stream)
                .environment(view)
                .environment(music)
                .environment(shazam)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .frame(width: 320)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        SongRow(stream: .preview)

        Text("Discovered")
            .font(.subheadline)
            .bold()
            .foregroundStyle(.gray)
            .padding(.horizontal)
            .padding(.top, 12)
        EditableList(
            Binding(
                get: { [ShazamStream.preview, ShazamStream.preview] },
                set: { _ in }
            )
        ) { $stream in
            SongRowMini(stream: stream)
        }
        .listStyle(.plain)
    }
    .modelContainer(PreviewSampleData.container)
    .environment(ShazamProvider())
    .environment(SheetProvider())
    .environment(MusicProvider())
}
