//
//  MapView.swift
//  Abra
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @EnvironmentObject private var vm: ViewModel
    var shazams: [ShazamStream]
    @Binding var position: MapCameraPosition
    
    var body: some View {
        Map(position: $position, selection: $vm.mapSelection) {
            ForEach(shazams, id: \.id) { shazam in
                Annotation(shazam.title, coordinate: shazam.coordinate) {
                    AsyncImage(url: shazam.artworkURL) { image in
                        image
                            .resizable()
                    } placeholder: {
                        ProgressView()
                            .scaledToFit()
                    }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
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
        .onChange(of: vm.selectedSS) {
            if (vm.selectedSS != nil) {
                // In case the keyboard is open & a SongRow was clicked, hide it
                // This is hacky, but works!
                hideKeyboard()
                
                // If the inspector is > than 0.50 of the screen, shrink it so it fits neatly behind our new sheet!
                if (vm.selectedDetent == .large) { vm.selectedDetent = .fraction(0.50) }
                
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
