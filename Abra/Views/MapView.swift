//
//  MapView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct MapView: View {
    @Environment(\.modelContext) private var context

    @Binding var detent: PresentationDetent
    @Binding var sheetSelection: ShazamStream?
    @Binding var groupSelection: ShazamStreamGroup?

    var shazams: [ShazamStream]

    @State private var mapProvider = MapProvider()

    var body: some View {
        Map(position: $mapProvider.position, selection: $mapProvider.selection) {
            ForEach(mapProvider.annotations) { shazam in
                Annotation(shazam.wrappedTitle, coordinate: shazam.coordinate) {
                    ShazamAnnotationView(artworkURL: shazam.wrappedArtworkURL)
                }
                .tag([shazam.wrappedId])
                .annotationTitles(.hidden)
            }

            ForEach(mapProvider.clusters) { cluster in
                Annotation("\(cluster.count)", coordinate: cluster.coordinate) {
                    ClusterAnnotationView(cluster: cluster)
                }
                .tag(cluster.streamIds)
                .annotationTitles(.hidden)
            }

            UserAnnotation() // User's location dot
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .readSize(onChange: handleSizeChange)
        .task {
            await mapProvider.setup(shazams)
        }
        .onMapCameraChange(frequency: .onEnd, handleCameraChange)
        .onChange(of: mapProvider.selection) {
            // Handle map annotation selection
            showSelectedAnnotation(mapProvider.selection)
        }
        .onChange(of: sheetSelection) {
            // ShazamStream selected from inspector
            if let coordinate = sheetSelection?.coordinate {
                showOnMap(coordinate)
            }
        }
        .onChange(of: shazams) {
            // Recalculate all clusters on change of ShazamStream db
            // Need to re-do data flow here because there's no way this is performant!
            Task {
                await mapProvider.setup(shazams)
            }
        }
    }

    /// Reads size for ClusterMap
    private func handleSizeChange(_ newValue: CGSize) {
        mapProvider.mapSize = newValue
    }

    /// Reloads clusters when map movement is finished
    private func handleCameraChange(_ context: MapCameraUpdateContext) {
        Task.detached {
            await mapProvider.reloadClusters(region: context.region)
        }
    }

    /// Opens the proper sheet when an annotation is tapped
    private func showSelectedAnnotation(_ selection: [PersistentIdentifier]?) {
        guard selection != nil else { return }

        // Clear so that repeat taps still trigger
        mapProvider.selection = nil

        if selection!.count == 1 {
            if let sstream = context.model(for: selection!.first!) as? ShazamStream {
                showOnMap(sstream.coordinate)
                sheetSelection = sstream // Open sheet
            }
        } else {
            // Create ShazamStreamGroup, feed to groupSelection
            let streams = context.fetchShazamStreams(fromIdentifiers: selection!)
            groupSelection = ShazamStreamGroup(wrapped: streams)
        }
    }

    /// Zooms and centers on a coordinate in the viewport
    private func showOnMap(_ coord: CLLocationCoordinate2D) {
        // In case the keyboard is open & a SongRow was clicked, hide it
        // This is hacky, but works!
        hideKeyboard()

        // If the inspector is > than 0.50 of the screen, shrink it so it fits neatly behind our new sheet!
        if detent == .fraction(0.999) { detent = .fraction(0.50) }

        // Center map
        // Offset latitude (move northward) by approximately 35% of the span
        // There's probably a better way to do this as this value is set based on my limited personal testing
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let offsetLatitude = coord.latitude + (span.latitudeDelta * -0.35)

        withAnimation {
            mapProvider.position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: offsetLatitude,
                    longitude: coord.longitude
                ),
                span: span
            ))
        }
    }
}

#Preview {
    @Previewable @State var position = MapCameraPosition.automatic

    MapView(detent: .constant(.height(65)), sheetSelection: .constant(nil), groupSelection: .constant(nil), shazams: [.preview, .preview, .preview])
        .modelContainer(PreviewSampleData.container)
}
