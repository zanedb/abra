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
                        .foregroundStyle(.gray)
                        .font(.subheading)
                }
                .padding(.bottom, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(spots, id: \.id) { spot in
                            spotView(spot)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 96)
                .background(.background)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }
    
    private func spotView(_ spot: Spot) -> some View {
        Button { view.show(spot) } label: {
            VStack(alignment: .center) {
                SpotIcon(symbol: spot.symbol, color: Color(spot.color), size: 48)
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
            Button("Delete", systemImage: "trash", role: .destructive, action: { pendingDeletion = spot; confirmationShown = true })
            Divider()
            Button("Shuffle", systemImage: "shuffle", action: { spot.play(music, shuffle: true) })
            Button("Play", systemImage: "play.fill", action: { spot.play(music) })
        }
        .confirmationDialog("This spot will be deleted from your Abra library, though the contents will not be deleted.", isPresented: $confirmationShown, titleVisibility: .visible) {
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
