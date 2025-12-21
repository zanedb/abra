//
//  SongDiscovered.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongDiscovered: View {
    @Environment(\.modelContext) var modelContext
    @Environment(SheetProvider.self) private var view
    
    @Bindable var stream: ShazamStream
    @Query(sort: \Spot.updatedAt, order: .reverse) private var spots: [Spot]
    // TODO: sort by location, updatedAt, limit to 5
    private var recentNearbySpots: [Spot] {
        spots.sorted { $0.updatedAt > $1.updatedAt }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Discovered")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            
            Wrapper {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stream.timestamp, style: .time)
                            .fontWeight(.medium)
                            .padding(.bottom, 2)
                        Text(stream.timestamp, style: .date)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    
                    Spacer()
                        
                    VStack(alignment: .trailing, spacing: 0) {
                        Menu {
                            ForEach(recentNearbySpots, id: \.id) { spot in
                                Toggle(spot.name, systemImage: spot.symbol, isOn: spotBinding(spot, stream: stream))
                                    .tint(Color(spot.color))
                            }
                            Divider()
                            Button("New Spot", systemImage: "plus", action: createSpot)
                        } label: {
                            Text(stream.spot?.name ?? "Choose Spot")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .imageScale(.small)
                                .font(.subheadline)
                        }
                        .padding(.bottom, 5)
                        
                        Text(stream.cityState)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func spotBinding(_ spot: Spot, stream: ShazamStream) -> Binding<Bool> {
        Binding<Bool>(
            get: { stream.spot == spot },
            set: { stream.spot = $0 ? spot : nil
            })
    }
    
    }
    
    private func createSpot() {
        // Create new Spot, insert into modelContext, and open for immediate editing
        let spot = Spot(locationFrom: stream, streams: [stream])
        modelContext.insert(spot)
        view.show(spot)
        
        Task {
            spot.appendNearbyShazamStreams(modelContext)
        }
    }
}

#Preview {
    EmptyView()
        .inspector(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
        .modelContainer(PreviewSampleData.container)
}
