import MusicKit
import SwiftData
import SwiftUI
import Kingfisher

struct SongVersionPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicProvider.self) private var music

    let stream: ShazamStream
    let songs: [Song]

    @State private var selectedSongID: MusicItemID?
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    init(stream: ShazamStream, initialSongs: [Song]) {
        self.stream = stream
        songs = initialSongs.filter {
            SongVersionMatcher.isMatch(title: $0.title, artist: $0.artistName,
                                       originalTitle: stream.title, originalArtist: stream.artist)
        }
    }

    var body: some View {
        NavigationStack {
            List(songs) { song in
                Button {
                    selectVersion(song)
                } label: {
                    SongVersionRow(song: song, isSelected: selectedSongID == song.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Updating song version…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                } else if songs.isEmpty {
                    ContentUnavailableView("No Versions Available", systemImage: "music.note")
                }
            }
            .navigationTitle("Choose Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm version", systemImage: "checkmark", action: confirmVersion)
                        .labelStyle(.iconOnly)
                        .backportCircleSymbolVariant(fill: false)
                        .disabled(selectedSongID == nil || isSaving)
                }
            }
            .onDisappear { saveTask?.cancel() }
            .alert("Couldn’t Re-link Song", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func selectVersion(_ song: Song) {
        selectedSongID = song.id
    }

    private func confirmVersion() {
        guard !isSaving, let song = songs.first(where: { $0.id == selectedSongID }) else { return }
        isSaving = true
        saveTask = Task { @MainActor in
            defer { isSaving = false }
            // Use the same artwork URL as the header, avoiding an old image on return.
            if let artworkURL = song.artwork?.url(width: 600, height: 600) {
                _ = try? await KingfisherManager.shared.retrieveImage(with: artworkURL)
            }
            do {
                try Task.checkCancellation()
                try music.relink(stream, to: song)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                saveErrorMessage = error.localizedDescription
                showingSaveError = true
            }
        }
    }
}
