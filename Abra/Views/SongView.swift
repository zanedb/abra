//
//  SongView.swift
//  Abra
//

import MusadoraKit
import MusicKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.toastProvider) private var toast
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(MusicProvider.self) private var music
    @Environment(ShazamProvider.self) private var shazam
    @Environment(SheetProvider.self) private var sheetProvider

    private let initialStream: ShazamStream
    private let onSongChange: ((ShazamStream) -> Void)?
    @State private var stream: ShazamStream

    init(stream: ShazamStream, onSongChange: ((ShazamStream) -> Void)? = nil) {
        initialStream = stream
        self.onSongChange = onSongChange
        _stream = State(initialValue: stream)
    }

    @State private var showingConfirmation = false
    @State private var showingPlaylistPicker = false
    @State private var showingLocationPicker = false
    @State private var inLibrary: Bool = false
    @State private var sheetHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var navigationHeight: CGFloat?

    private var expansion: CGFloat {
        guard let navigationHeight else { return 0 }
        return ((sheetHeight - navigationHeight - 300) / (UIScreen.main.bounds.height - 520))
            .clamped(to: 0...1)
    }

    @State private var selectedDetent: PresentationDetent = .fraction(0.50)
    @State private var spotToPresent: Spot? = nil
    @State private var detentBeforeSpot: PresentationDetent? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                SongInfo(stream: stream, expansion: expansion)
                    .id(stream.appleMusicID)

                Moments(stream: stream)

                SongDiscovered(stream: stream, onShowSpot: showSpot)

                SongDetails(stream: stream)
            }
            .toolbar {
                ToolbarItems
            }
            .toolbar(toast.isVisible && navigationHeight != nil ? .hidden : .automatic, for: .bottomBar)
            .animation(.easeInOut(duration: 0.25), value: toast.isVisible)
            .popover(isPresented: $showingPlaylistPicker) {
                PlaylistPicker(stream: stream)
                    .presentationDetents([.large])
            }
            .popover(isPresented: $showingLocationPicker) {
                LocationPicker(stream: stream)
                    .presentationDetents([.large])
            }
            .task(id: stream.appleMusicID) {
                inLibrary = false
                guard let appleMusicID = stream.appleMusicID else { return }

                // Check if song exists in user's library
                let song = try? await MLibrary.song(
                    id: MusicItemID(stringLiteral: appleMusicID)
                )
                guard !Task.isCancelled, stream.appleMusicID == appleMusicID else { return }
                if song != nil { inLibrary = true }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: {
                contentHeight = $0
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: {
            sheetHeight = $0
        }
        .onChange(of: [sheetHeight, contentHeight]) {
            measureNavigationHeight()
        }
        .withToastOverlay(using: toast)
        .onChange(of: initialStream) { _, newValue in
            stream = newValue
        }
        .presentationDetents([.fraction(0.50), .large], selection: $selectedDetent)
        .sheet(item: $spotToPresent) { spot in
            SpotView(spot: spot, onShowSong: showSongFromSpot)
                .presentationDetents([.fraction(0.50), .large])
                .presentationInspector()
                .prefersEdgeAttachedInCompactHeight()
        }
        .onChange(of: spotToPresent) { oldValue, newValue in
            if let newValue {
                sheetProvider.showSpotOnMap(newValue)
            } else if let oldValue {
                sheetProvider.dismissSpotOnMap(oldValue)
            }
            if newValue == nil, let prior = detentBeforeSpot {
                selectedDetent = prior
                detentBeforeSpot = nil
            }
        }
    }

    private func showSpot(_ spot: Spot) {
        if selectedDetent == .large {
            detentBeforeSpot = .large
            selectedDetent = .fraction(0.50)
        }
        spotToPresent = spot
    }

    private func showSongFromSpot(_ song: ShazamStream) {
        // Update the existing song sheet before dismissing its spot sheet.
        onSongChange?(song)
        stream = song
        spotToPresent = nil
    }

    private func measureNavigationHeight() {
        guard navigationHeight == nil,
            sheetHeight > 0, contentHeight > 0
        else { return }

        // The toolbar stays visible until this initial measurement is captured,
        // even when a toast was already present as the sheet opened.
        navigationHeight = sheetHeight - contentHeight
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            DismissButton()
        }

        if !music.isSongUnavailable(stream.appleMusicID), let url = stream.appleMusicURL {
            ToolbarItem(placement: .topBarLeading) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Apple Music Link")
                .backportCircleSymbolVariant(fill: false)
            }
        }

        if !music.isSongUnavailable(stream.appleMusicID), let appleMusicID = stream.appleMusicID {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    addToMusicLibrary(appleMusicID)
                } label: {
                    Image(
                        systemName: inLibrary ? "checkmark" : "plus"
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
                Button(
                    "Delete from Abra",
                    systemImage:
                        "trash.fill",
                    role: .destructive,
                    action: {
                        showingConfirmation = true
                    }
                )

                if (stream.latitude == -1 && stream.longitude == -1)
                    || (stream.latitude == 0 && stream.longitude == 0)
                    || stream.approximateLocationRadius != nil
                {
                    Divider()
                    Button(
                        (stream.latitude == -1 && stream.longitude == -1)
                            || (stream.latitude == 0 && stream.longitude == 0)
                            ? "Add Location" : "Add Precise Location",
                        systemImage:
                            "location.fill.viewfinder",
                        action: {
                            showingLocationPicker.toggle()
                        }
                    )
                }

                Divider()

                if !music.isSongUnavailable(stream.appleMusicID),
                    let appleMusicID = stream.appleMusicID
                {
                    Button(
                        "Add to Queue",
                        systemImage:
                            "text.line.last.and.arrowtriangle.forward",
                        action: {
                            Task {
                                if await music.queue(
                                    ids: [appleMusicID],
                                    position: .tail
                                ) {
                                    toast.show(message: "Added to Queue", type: .success, symbol: "text.line.last.and.arrowtriangle.forward")
                                }
                            }
                        }
                    )
                    Button(
                        "Play Next",
                        systemImage:
                            "text.line.first.and.arrowtriangle.forward",
                        action: {
                            Task {
                                if await music.queue(
                                    ids: [appleMusicID],
                                    position: .afterCurrentEntry
                                ) {
                                    toast.show(message: "Playing Next", type: .success, symbol: "text.line.first.and.arrowtriangle.forward")
                                }
                            }
                        }
                    )
                }

                if !music.isSongUnavailable(stream.appleMusicID), let appleMusicID = stream.appleMusicID {
                    ControlGroup {
                        Button(
                            inLibrary ? "Added" : "Add",
                            systemImage: inLibrary ? "checkmark" : "plus",
                            action: {
                                addToMusicLibrary(appleMusicID)
                            }
                        )

                        Button(
                            "Playlist",
                            systemImage: "music.note.list",
                            action: {
                                showingPlaylistPicker.toggle()
                            }
                        )

                        if let url = stream.appleMusicURL,
                            let link = stream.songLink
                        {
                            Menu("Share", systemImage: "square.and.arrow.up") {
                                ShareLink("Music", item: url)
                                ShareLink("Song.link", item: link)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More Options")
            .confirmationDialog(
                "This song will be deleted from your Abra and Shazam libraries.",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Song", role: .destructive, action: remove)
            }
        }
    }

    private func addToMusicLibrary(_ appleMusicID: String) {
        guard !inLibrary else { return }

        Task {
            inLibrary = try await MLibrary.addSong(
                id: MusicItemID(stringLiteral: appleMusicID)
            )
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
