//
//  MapView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct MapView: UIViewRepresentable {
    @Environment(SheetProvider.self) private var sheet

    @Query(filter: #Predicate<ShazamStream> { $0.spot == nil },
           sort: \ShazamStream.timestamp, order: .reverse)
    private var shazams: [ShazamStream]

    @Query( /* filter: #Predicate<Spot> { $0.type == .place }, */
        sort: \Spot.updatedAt, order: .reverse
    )
    private var spots: [Spot]

    var modelContext: ModelContext

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        mapView.showsUserLocation = true
        mapView.showsUserTrackingButton = true
        mapView.showsCompass = true
        mapView.setUserTrackingMode(.follow, animated: true)

        mapView.register(ShazamAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(ShazamAnnotation.self))
        mapView.register(ShazamClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MKClusterAnnotation.self))
        mapView.register(SpotAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(SpotAnnotation.self))

        // TODO: Proper Concurrency support here
        withObservationTracking(of: sheet.now) { _ in
            showAnnotation(sheet.now, on: mapView)
        }

        return mapView
    }

    /// Zooms and centers an annotation in the viewport
    private func showAnnotation(_ now: SheetProvider.ViewState, on mapView: MKMapView) {
        var coord: CLLocationCoordinate2D

        switch now {
        case let .spot(spot):
            coord = spot.coordinate
        case let .stream(stream):
            coord = stream.coordinate
        default:
            return
        }

        // In case the keyboard is open & a SongRow was clicked, hide it
        // This is hacky, but works!
        hideKeyboard()

        // Center map
        // Offset latitude (move northward) by approximately 35% of the span
        // There's probably a better way to do this as this value is set based on my limited personal testing
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let offsetLatitude = coord.latitude + (span.latitudeDelta * -0.35)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: offsetLatitude,
                longitude: coord.longitude
            ),
            span: span
        )

        mapView.setRegion(region, animated: true)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("UI view did update")

        // Quick hash check - bail early if nothing changed
        var hasher = Hasher()
        shazams.hash(into: &hasher)
        spots.hash(into: &hasher)
        let newDataHash = hasher.finalize()

        if context.coordinator.lastDataHash == newDataHash {
            print("No data changes detected, skipping update")
            return
        }
        context.coordinator.lastDataHash = newDataHash

        // Get current annotations (excluding user location and clusters)
        let currentAnnotations = mapView.annotations.filter {
            !($0 is MKUserLocation) && !($0 is MKClusterAnnotation)
        }

        let newShazamAnnotations = shazams.map { ShazamAnnotation(shazamStream: $0) }
        let newSpotAnnotations = spots.map { SpotAnnotation(spot: $0) }
        let newAnnotations: [MKAnnotation] = newShazamAnnotations + newSpotAnnotations

        // Diff annotations
        let annotationsToRemove = currentAnnotations.filter { currentAnnotation in
            !newAnnotations.contains { newAnnotation in
                annotationsAreEqual(currentAnnotation, newAnnotation)
            }
        }

        let annotationsToAdd = newAnnotations.filter { newAnnotation in
            !currentAnnotations.contains { currentAnnotation in
                annotationsAreEqual(currentAnnotation, newAnnotation)
            }
        }

        // Apply changes
        if !annotationsToRemove.isEmpty {
            mapView.removeAnnotations(annotationsToRemove)
        }

        if !annotationsToAdd.isEmpty {
            mapView.addAnnotations(annotationsToAdd)
        }

        print("Removed: \(annotationsToRemove.count), Added: \(annotationsToAdd.count)")
    }

    private func annotationsAreEqual(_ lhs: MKAnnotation, _ rhs: MKAnnotation) -> Bool {
        switch (lhs, rhs) {
        case let (shazamL as ShazamAnnotation, shazamR as ShazamAnnotation):
            return shazamL.shazamStream == shazamR.shazamStream
        case let (spotL as SpotAnnotation, spotR as SpotAnnotation):
            return spotL.spot == spotR.spot
        default:
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private var parent: MapView
        var lastDataHash: Int = 0

        init(_ parent: MapView) {
            self.parent = parent
            super.init()
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case is ShazamAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(ShazamAnnotation.self), for: annotation)
                view.clusteringIdentifier = NSStringFromClass(ShazamAnnotation.self)
                return view
            case is SpotAnnotation:
                return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(SpotAnnotation.self), for: annotation)
            case is MKClusterAnnotation:
                return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(MKClusterAnnotation.self), for: annotation)
            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            switch annotation {
            case let shazamAnnotation as ShazamAnnotation:
                print("Selected \(shazamAnnotation.shazamStream.title)")
                parent.sheet.show(shazamAnnotation.shazamStream)
            case let spotAnnotation as SpotAnnotation:
                print("Selected \(spotAnnotation.spot.name)")
                parent.sheet.show(spotAnnotation.spot)
            case let clusterAnnotation as MKClusterAnnotation:
                print("Selected cluster with \(clusterAnnotation.memberAnnotations.count) members")
                if let shazamAnnotations = clusterAnnotation.memberAnnotations as? [ShazamAnnotation] {
                    let streams = shazamAnnotations.compactMap(\.shazamStream)
                    print("Cluster has \(streams.count) Shazam streams")
                    let spot = Spot(locationFrom: streams.first!, type: .place, streams: streams, modelContext: parent.modelContext)
                    parent.modelContext.insert(spot)
                    parent.sheet.show(spot)
                    
                    Task {
                        spot.appendNearbyShazamStreams(parent.modelContext)
                    }
                }
            default:
                return
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
            switch annotation {
            case let shazamAnnotation as ShazamAnnotation:
                print("Deselected \(shazamAnnotation.shazamStream.title)")
                parent.sheet.stream = nil
            case let spotAnnotation as SpotAnnotation:
                print("Deselected \(spotAnnotation.spot.name)")
                parent.sheet.spot = nil
            case let clusterAnnotation as MKClusterAnnotation:
                print("Deselected cluster with \(clusterAnnotation.memberAnnotations.count) members")
            default:
                return
            }
        }
    }
}

#Preview {
    MapView(modelContext: PreviewSampleData.container.mainContext)
        .edgesIgnoringSafeArea(.all)
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
}
