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
                    Text(
                        mapItem.addressRepresentations?.cityWithContext
                            ?? "city"
                            //mapItem.addressRepresentations?.cityName ?? mapItem.address?.shortAddress?.replacingOccurrences(of: ", ", with: "\n") ?? ""
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
    var onShowSpot: (Spot) -> Void

    @State var mapItems: [MKMapItem] = []

    // The idea here is that if it's a relatively nearby area, and maybe the GPS is a little off, or it's wide open space, it'll prompt to add to semi-related spots
    // But.. do we need to make this calculation on every view open?
    // Is it even helpful?
    // Also.. unfortunately we can't move the predicate logic into the @Query bc the compiler.. the compiler.. it's.. it's.. you know.
    @Query(sort: \Spot.updatedAt, order: .reverse) private var spots: [Spot]
    private var approximateSpots: [Spot] {
        spots.filter {
            abs($0.latitude - stream.latitude) < 0.01
                && abs($0.longitude - stream.longitude) < 0.01
                && !$0.streams.contains(stream)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
        .reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save To Spot")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    if let existing = stream.spot {
                        Button {
                            onShowSpot(existing)
                        } label: {
                            SpotItem(existing)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(mapItems, id: \.identifier) { item in
                        Button {
                            if #available(iOS 26.0, *) {
                                let newSpot = Spot(mapItem: item)
                                onShowSpot(newSpot)
                                Task {
                                    newSpot.appendNearbyShazamStreams(modelContext)
                                    await newSpot.affiliateMapItem(from: item)
                                }
                            }
                        } label: {
                            MapItemCard(mapItem: item)
                        }
                    }

                    ForEach(approximateSpots, id: \.id) { item in
                        Button {
                            stream.spot = item
                            onShowSpot(item)
                        } label: {
                            SpotItem(item)
                        }
                    }

                    Button {
                        let newSpot = Spot(locationFrom: stream)
                        onShowSpot(newSpot)
                        Task {
                            newSpot.appendNearbyShazamStreams(modelContext)
                        }
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
    }
    
    private func SpotItem(_ spot: Spot) -> some View {
        Wrapper {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: spot.sfSymbol)
                        .imageScale(.small)
                    Text(spot.name)
                        .fontWeight(.medium)
                }
                Text(spot.description)
            }
        }
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
