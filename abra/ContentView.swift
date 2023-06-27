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

private struct DetentKey: EnvironmentKey {
    static let defaultValue: PresentationDetent = .fraction(0.50)
}

extension EnvironmentValues {
    var selectedDetent: PresentationDetent {
        get { self[DetentKey.self] }
        set { self[DetentKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var locationViewModel = Location()

    @ObservedObject private var shazam = Shazam()
    @ObservedObject var mapViewModel = MapViewModel()
    @StateObject var music = MusicController.shared.music
    @State private var selectedDetent: PresentationDetent = .fraction(0.50)
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    var body: some View {
        ZStack(alignment: .top) {
            UIKitMapView(streams: streams)
                .edgesIgnoringSafeArea(.all)
                .environmentObject(mapViewModel)
                        .environmentObject(locationViewModel)
                .sheet(isPresented: .constant(true)) {
                    SheetView(places: places, streams: streams, onSongTapped: updateCenter)
                        .environment(\.selectedDetent, selectedDetent)
                        .padding(.top, 4)
                        .presentationDetents([.height(65), .fraction(0.50), .large], largestUndimmed: .large, selection: $selectedDetent)
                        .interactiveDismissDisabled()
                        .ignoresSafeArea()
                }
                // TODO: after launch, jump to user's loc
                .onAppear {
                     mapViewModel.locateUserButtonPressed.toggle() // MARK: this doesn't work.
                }

            HStack(alignment: .top) {
                Spacer()
                VStack {
                    Button(action: {
                        mapViewModel.locateUserButtonPressed.toggle()
                    }) {
                        Image(systemName: "location")
                            .font(.system(size: 20))
                    }
                        .frame(width: 44, height: 44)
                        .background(.ultraThickMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.10))
                        )
                        .cornerRadius(8)
                }
                    .shadow(color: Color.primary.opacity(0.10), radius: 5, x: 0, y: 2)
            }.padding(.trailing)
        }
        .onAppear {
            // TODO: prompt first time users.. maybe?
            // TODO: handle no location perms
            locationViewModel.requestPermission()
        }
    }
    
    // MARK: this is called when a song is tapped in SongList, moves the map to it
    private func updateCenter(_ stream: SStream) {
        let coord = CLLocationCoordinate2D(latitude: stream.latitude, longitude: stream.longitude)
        mapViewModel.center = coord
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
