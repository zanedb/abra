import SwiftData
import SwiftUI

struct SpotSongRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music

    var stream: ShazamStream
    var spot: Spot
    var isLast: Bool
    var onViewSong: (ShazamStream) -> Void

    @State private var confirmationShown = false

    var body: some View {
        SongRowMini(
            stream: stream,
            onTapGesture: playPause,
            onViewSong: onViewSong,
            onRemoveFromSpot: { confirmationShown = true }
        )
        .padding()
        .padding(.bottom, isLast ? 12 : -4)
        .padding(.top, -4)
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
            Button("Remove from Spot", systemImage: "mappin.slash", role: .destructive) {
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
            "This song will be removed from this spot. It will remain in your Abra and Shazam libraries.",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("Remove from Spot", role: .destructive, action: removeFromSpot)
        }
    }

    private func playPause() {
        guard let appleMusicID = stream.appleMusicID else { return }
        music.playPause(id: appleMusicID)
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

    private func removeFromSpot() {
        withAnimation {
            spot.shazamStreams?.removeAll { $0 == stream }
            if stream.spot == spot {
                stream.spot = nil
            }
            spot.updatedAt = .now
            try? modelContext.save()
        }
    }
}
