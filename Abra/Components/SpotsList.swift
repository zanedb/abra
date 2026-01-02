//
//  SpotsList.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SpotsList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SheetProvider.self) private var view
    @Environment(MusicProvider.self) private var music

    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]

    @State private var pendingDeletion: Spot? = nil
    @State private var confirmationShown: Bool = false

    var body: some View {
        if spots == [] {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Spots")
                        .font(.subheadline.weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                Wrapper(padding: false) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(spots, id: \.id) { spot in
                                spotView(spot)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private func spotView(_ spot: Spot) -> some View {
        Button {
            view.show(spot)
        } label: {
            VStack(alignment: .center) {
                SpotIcon(
                    symbol: spot.sfSymbol,
                    color: Color(spot.color),
                    size: 48
                )
                Text(spot.name)
                    .font(.system(size: 12))
                    .tint(.primary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .contextMenu {
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
                action: { spot.play(music, shuffle: true) }
            )

            Divider()

            Button(
                "Delete from Abra",
                systemImage: "trash",
                role: .destructive,
                action: {
                    pendingDeletion = spot
                    confirmationShown = true
                }
            )
        }
        .confirmationDialog(
            "This spot will be deleted from your Abra library, though the contents will not be deleted.",
            isPresented: $confirmationShown,
            titleVisibility: .visible
        ) {
            Button("Delete Spot", role: .destructive, action: deleteSpot)
        }
    }

    private func deleteSpots(offsets: IndexSet) {
        withAnimation {
            offsets.map { spots[$0] }.forEach(modelContext.delete)
            try? modelContext.save()
        }
    }

    private func deleteSpot() {
        confirmationShown = false
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil

        withAnimation {
            modelContext.delete(pending)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            SpotsList()
                .modelContainer(PreviewSampleData.container)
                .environment(SheetProvider())
                .environment(MusicProvider())
                .padding()
        }
        .background(.ultraThickMaterial)
    }
}
