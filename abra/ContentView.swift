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
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var locationViewModel = Location()

    @ObservedObject private var shazam = Shazam()
    @ObservedObject var mapViewModel = MapViewModel()
    @StateObject var music = MusicController.shared.music
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.updatedAt, ascending: false)],
        animation: .default)
    private var places: FetchedResults<Place>
    
    var body: some View {
        ZStack(alignment: .top) {
            UIKitMapView(streams: streams)
                .edgesIgnoringSafeArea(.all)
                .environmentObject(mapViewModel)
                .sheet(isPresented: .constant(true)) {
                    SheetView(places: places, streams: streams, onSongTapped: updateCenter)
                        .environmentObject(shazam)
                        .environment(\.selectedDetent, mapViewModel.selectedDetent)
                        .padding(.top, 4)
                        .readHeight() // track view height for map
                        .onPreferenceChange(HeightPreferenceKey.self) { height in
                            if let height {
                                mapViewModel.detentHeight = height
                            }
                        }
                        .presentationDetents([.height(65), .fraction(0.50), .large], largestUndimmed: .large, selection: $mapViewModel.selectedDetent)
                        .interactiveDismissDisabled()
                        .ignoresSafeArea()
                        .sheet(isPresented: $shazam.searching) {
                            Searching()
                                .presentationDetents([.fraction(0.50)]/*, largestUndimmed: .large*/)
                                .interactiveDismissDisabled()
                                .presentationDragIndicator(.hidden)
                                .overlay(
                                    Button { shazam.stopRecognition() } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 36))
                                            .symbolRenderingMode(.hierarchical)
                                            .padding(.vertical)
                                            .padding(.trailing, -5)
                                    },
                                    alignment: .topTrailing
                                )
                        }
                }

            
            HStack(alignment: .top) {
                Spacer()
                LocateButton()
                    .environmentObject(mapViewModel)
            }
                .padding(.trailing, 10)
        }
        .onChange(of: scenePhase) { phase in
            // MARK: on app close, save last active region to defaults, next launch opens there
            if phase == .inactive {
                UserDefaults.standard.set(mapViewModel.center.latitude, forKey: "LatCoord")
                UserDefaults.standard.set(mapViewModel.center.longitude, forKey: "LongCoord")
            }
        }
        .onAppear {
            // TODO: prompt first time users.. maybe?
            // TODO: handle no location perms
            locationViewModel.requestPermission()
        }
        // MARK: this is a workaround to track taps outside of Searching() sheet and dismiss
        // it works, except the rectangle can't dim the primary bottom sheet
        // perhaps a custom detents modifier is in order..
        // or apple could just get their shit together! this is a common use case! it's in your damn apps!
        /*.overlay(
            shazam.searching ?
                Rectangle()
                    .opacity(0.15)
                    .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        shazam.stopRecognition()
                    }
                : nil
        )*/
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
