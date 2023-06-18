//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import CoreLocation
import MapKit
import MusicKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var locationManager: CLLocationManager?

    @ObservedObject private var shazam = Shazam()
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3316876, longitude: -122.0327261), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    var body: some View {
        ZStack(alignment: .top) {
            UIKitMapView(region: region, streams: Array(streams))
                .edgesIgnoringSafeArea(.all)
                .sheet(isPresented: .constant(true)) {
                    UISheet {
                        NavigationStack {
                            SheetView(streams: Array(streams))
                        }
                    }
                        .interactiveDismissDisabled()
                        .ignoresSafeArea()
                }

            HStack(alignment: .top) {
                Spacer()
                ShazamButton(searching: shazam.searching, start: shazam.startRecognition, stop: shazam.stopRecognition, size: 36, fill: true, color: true)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.20))
                    )
                    .cornerRadius(5)
            }.padding(.trailing)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
