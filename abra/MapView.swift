//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import SwiftData
import SDWebImageSwiftUI

struct MapView: View {
    @EnvironmentObject private var vm: ViewModel
    var shazams: [ShazamStream]
    @Binding var position: MapCameraPosition
    
    var body: some View {
        Map(position: $position, selection: $vm.selectedTag) {
            ForEach(shazams, id: \.id) { shazam in
                Annotation(shazam.title, coordinate: shazam.coordinate) {
                    WebImage(url: shazam.artworkURL)
                        .resizable()
                        .placeholder {
                            ProgressView()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
                        .shadow(radius: 3, x: 2, y: 2)
                        .tag(shazam.id)
                }
                .annotationTitles(.hidden)
            }
            
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }
}

#Preview {
    MapView(shazams: [.preview], position: .constant(.automatic))
        .environmentObject(ViewModel())
        .modelContainer(PreviewSampleData.container)
}
