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
                .sheet(isPresented: .constant(true)) {
                    SheetView(places: places, streams: streams, onSongTapped: updateCenter)
                        .environmentObject(shazam)
                        .environment(\.selectedDetent, selectedDetent)
                        .padding(.top, 4)
                        .presentationDetents([.height(65), .fraction(0.50), .large], largestUndimmed: .large, selection: $selectedDetent)
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
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.60))
                    }
                        .frame(width: 42, height: 42)
                        .background(.ultraThickMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.10))
                        )
                        .cornerRadius(8)
                }
                    .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
            }.padding(.trailing, 10)
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
