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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                } else {
                    Text(mapItem.name ?? "")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
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

    // This way, we can sort the nearby spots & map items by distance from stream for more relevant suggestions
    private enum SpotOrMapItem: Identifiable {
        case spot(Spot)
        case mapItem(MKMapItem)

        var id: String {
            switch self {
            case .spot(let s): "spot-\(s.id)"
            case .mapItem(let m): "mapItem-\(m.identifier?.rawValue ?? m.name ?? m.placemark.title ?? "unknown")"
            }
        }

        func distance(from streamLocation: CLLocation) -> CLLocationDistance {
            switch self {
            case .spot(let s):
                return CLLocation(latitude: s.latitude, longitude: s.longitude).distance(from: streamLocation)
            case .mapItem(let m):
                let c = m.placemark.coordinate
                return CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: streamLocation)
            }
        }
    }

    private var sortedItems: [SpotOrMapItem] {
        let all: [SpotOrMapItem] =
            approximateSpots.map { .spot($0) } + mapItems.map { .mapItem($0) }
        return all.sorted { $0.distance(from: stream.location) < $1.distance(from: stream.location) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Spot")
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
                        .contextMenu {
                            Button(
                                "Remove from Spot",
                                systemImage: "mappin.slash",
                                action: {
                                    stream.spot = nil
                                }
                            )
                        }
                    }
                    
                    ForEach(sortedItems) { item in
                        switch item {
                        case .spot(let spot):
                            Button {
                                stream.spot = spot
                                onShowSpot(spot)
                            } label: {
                                SpotItem(spot)
                            }
                        case .mapItem(let mapItem):
                            Button {
                                if #available(iOS 26.0, *) {
                                    let newSpot = Spot(mapItem: mapItem)
                                    onShowSpot(newSpot)
                                    Task {
                                        newSpot.appendNearbyShazamStreams(modelContext)
                                        await newSpot.affiliateMapItem(from: mapItem)
                                    }
                                }
                            } label: {
                                MapItemCard(mapItem: mapItem)
                            }
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
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
