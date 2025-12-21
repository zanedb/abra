//
//  SongDiscovered.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct MapItemCard: View {
    var mapItem: MKMapItem

    var body: some View {
        Wrapper {
            VStack(alignment: .leading, spacing: 4) {
                Text(mapItem.name ?? "name")
                    .fontWeight(.medium)

                if #available(iOS 26.0, *) {
                    //                    Text(mapItem.address?.shortAddress?.replacingOccurrences(of: ", ", with: "\n") ?? "")
                    Text(
                        (mapItem.addressRepresentations?.cityWithContext) ?? ""
                    )
                } else {
                    Text(mapItem.name ?? "")
                }
            }
        }
    }
}

struct SongDiscovered: View {
    @Environment(\.modelContext) var modelContext
    @Environment(SheetProvider.self) private var view

    @Bindable var stream: ShazamStream

    @State var mapItems: [MKMapItem] = []
    @State var spot: Spot?

    @Query(sort: \Spot.updatedAt, order: .reverse) private var spots: [Spot]

    // TODO: sort by location, updatedAt, limit to 5
    private var recentNearbySpots: [Spot] {
        spots.sorted { $0.updatedAt > $1.updatedAt }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save To Spot")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    if let spot = stream.spot {
                        Wrapper {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(spot.name)
                                    .fontWeight(.medium)
                                Text(spot.description)
                            }
                        }
                    }
                    
                    ForEach(mapItems, id: \.identifier) { item in
                        Button {
                            if #available(iOS 26.0, *) {
                                spot = Spot(mapItem: item)
                                spot?.appendNearbyShazamStreams(modelContext)
                            }
                        } label: {
                            MapItemCard(mapItem: item)
                        }
                    }

                    Button {
                        //
                    } label: {
                        Wrapper {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .frame(minWidth: 100)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .task(id: stream.persistentModelID) {
            let search = MKLocalSearch(
                request: .init(center: stream.coordinate, radius: 20)
            )
            let response = try? await search.start()
            mapItems = response?.mapItems ?? []

            if #available(iOS 26.0, *) {
                if let request = MKReverseGeocodingRequest(
                    location: stream.location
                ) {
                    let items = try? await request.mapItems
                    if let mapitem = items?.first {
                        mapItems.append(mapitem)
                    }
                }
            } else {
                // Fallback on earlier versions
                // CLPlacemark or some bullshit ugh
                // do i even need to support 18?
            }
        }
        .sheet(item: $spot) { spot in
            SpotView(spot: spot)
                .presentationDetents([.fraction(0.50), .large])
                .presentationInspector()
                .prefersEdgeAttachedInCompactHeight()
        }
    }

    private func spotBinding(_ spot: Spot, stream: ShazamStream) -> Binding<
        Bool
    > {
        Binding<Bool>(
            get: { stream.spot == spot },
            set: {
                stream.spot = $0 ? spot : nil
            }
        )
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
    VStack {}
        .sheet(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .presentationDetents([.medium, .large])
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
