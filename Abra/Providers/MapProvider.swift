//
//  MapProvider.swift
//  Abra
//

import ClusterMap
import ClusterMapSwiftUI
import Foundation
import MapKit
import SwiftData
import SwiftUI

struct ShazamStreamRepresentable: Identifiable, Hashable, CoordinateIdentifiable {
    var id = UUID()
    var coordinate: CLLocationCoordinate2D
    var wrappedId: PersistentIdentifier
    var wrappedTitle: String
    var wrappedArtworkURL: URL
}

struct ShazamClusterAnnotation: Identifiable, Hashable {
    var id = UUID()
    var coordinate: CLLocationCoordinate2D
    var streamIds: [PersistentIdentifier]
    var count: Int {
        streamIds.count
    }
}

@Observable class MapProvider {
    var mapSize: CGSize = .init(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    var annotations: [ShazamStreamRepresentable] = []
    var clusters: [ShazamClusterAnnotation] = []
    var position: MapCameraPosition = .automatic
    var selection: [PersistentIdentifier]?

    let clusterConfig = ClusterManager<ShazamStreamRepresentable>.Configuration(
        maxZoomLevel: 20, // default is 20
        cellSizeForZoomLevel: { zoom in
            switch zoom {
            case 13...18: return CGSize(width: 32, height: 32)
            case 19...: return CGSize(width: 16, height: 16)
            default: return CGSize(width: 88, height: 88)
            }
        }
    )

    var clusterManager: ClusterManager<ShazamStreamRepresentable>

    init() {
        clusterManager = ClusterManager<ShazamStreamRepresentable>(configuration: clusterConfig)
    }

    func setup(
        _ shazams: [ShazamStream]
    ) async {
        let shazamRepresentables: [ShazamStreamRepresentable] = shazams.map { ShazamStreamRepresentable(coordinate: $0.coordinate, wrappedId: $0.id, wrappedTitle: $0.title, wrappedArtworkURL: $0.artworkURL) }
        await clusterManager.add(shazamRepresentables)
        if let currentRegion = position.region {
            await reloadClusters(region: currentRegion)
        }
    }

    func reloadClusters(region: MKCoordinateRegion) async {
        async let changes = clusterManager.reload(
            mapViewSize: mapSize,
            coordinateRegion: region
        )
        await applyChanges(changes)
    }

    @MainActor
    func applyChanges(_ difference: ClusterManager<ShazamStreamRepresentable>.Difference) {
        for removal in difference.removals {
            switch removal {
            case .annotation(let annotation):
                annotations.removeAll { $0.id == annotation.id }
            case .cluster(let clusterAnnotation):
                clusters.removeAll { $0.id == clusterAnnotation.id }
            }
        }
        for insertion in difference.insertions {
            switch insertion {
            case .annotation(let newItem):
                annotations.append(newItem)
            case .cluster(let newItem):
                clusters.append(
                    ShazamClusterAnnotation(
                        id: newItem.id,
                        coordinate: newItem.coordinate,
                        streamIds: newItem.memberAnnotations.compactMap(\.wrappedId)
                    )
                )
            }
        }
    }
}
