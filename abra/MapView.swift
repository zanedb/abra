//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import SwiftData
import CoreData
import Combine

struct MapView: View {
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var body: some View {
        Map {
            ForEach(shazams, id: \.id) { shazam in
                Annotation(shazam.title, coordinate: shazam.coordinate) {
                    MapPin(stream: shazam)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }
}

enum MapDefaults {
    static let coordinate = CLLocationCoordinate2D(latitude: UserDefaults.standard.double(forKey: "LatCoord"), longitude: UserDefaults.standard.double(forKey: "LongCoord"))
    static let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
}
