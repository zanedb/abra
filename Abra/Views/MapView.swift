//
//  MapView.swift
//  Abra
//

import Kingfisher
import MapKit
import SwiftData
import SwiftUI

struct MapView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var vm: ViewModel
    var shazams: [ShazamStream]
    @Binding var position: MapCameraPosition

    @State private var mapSelection: PersistentIdentifier?
    var body: some View {
            ForEach(shazams, id: \.id) { shazam in
        Map(position: $position, selection: $mapSelection) {
                Annotation(shazam.title, coordinate: shazam.coordinate) {
                    KFImage(shazam.artworkURL)
                        .resizable()
                        .placeholder { ProgressView() }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(2)
                        .shadow(radius: 3, x: 2, y: 2)
                }
                .annotationTitles(.hidden)
                .tag(shazam.id)
            }

            UserAnnotation() // User's location dot
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        // Handle ShazamStream selected from list
        .onChange(of: mapSelection) {
            // Handle ShazamStream tapped from map annotation
            guard mapSelection != nil else { return }

            if let sstream = context.model(for: mapSelection!) as? ShazamStream {
                vm.selectedSS = sstream
                mapSelection = nil // Clear so that repeat taps still trigger
            }
        }
        .onChange(of: vm.selectedSS) {
            // Handle ShazamStream selected, either from map or list
            handleSelectionChange()
        }
            }
        }
    }

    private func handleSelectionChange() {
        guard vm.selectedSS != nil else { return }

        // In case the keyboard is open & a SongRow was clicked, hide it
        // This is hacky, but works!
        hideKeyboard()

        // If the inspector is > than 0.50 of the screen, shrink it so it fits neatly behind our new sheet!
        if vm.selectedDetent == .large { vm.selectedDetent = .fraction(0.50) }

        // Center map
        // Offset latitude (move northward) by approximately 35% of the span
        // There's probably a better way to do this as this value is set based on my limited personal testing
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let offsetLatitude = vm.selectedSS!.latitude + (span.latitudeDelta * -0.35)

        withAnimation {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: offsetLatitude,
                    longitude: vm.selectedSS!.longitude
                ),
                span: span
            ))
        }
    }
}

#Preview {
    MapView(shazams: [.preview], position: .constant(.automatic))
        .environmentObject(ViewModel())
        .modelContainer(PreviewSampleData.container)
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
