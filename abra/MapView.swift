//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import CoreData

struct MapLocation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var artist: String
    var artworkURL: URL
    var appleMusicID: String
    var timestamp: Date
    var city: String
    var country: String
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MapView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject var location = LocationController.shared.loc
    @StateObject var music = MusicController.shared.music
    
    @State private var mapLocations = [MapLocation]()
    @State private var selectedPlace: MapLocation?
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3316876, longitude: -122.0327261), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    
    // TODO: generate MapLocation points from streams PROPERLY !!!!
    func convertLocs() {
        mapLocations = streams.map { stream in
            MapLocation(
                title: stream.title ?? "",
                artist: stream.artist ?? "",
                artworkURL: stream.artworkURL!, // fix
                appleMusicID: stream.appleMusicID ?? "",
                timestamp: stream.timestamp ?? Date(),
                city: stream.city ?? "",
                country: stream.country ?? "",
                latitude: stream.latitude,
                longitude: stream.longitude)
        }
    }
    
    var body: some View {
        ZStack {
            switch location.authorizationStatus {
            case .notDetermined:
                ProgressView()
                
            case .authorizedWhenInUse:
                Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: .constant(.none), annotationItems: mapLocations,
                    annotationContent: { mapLocation in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: mapLocation.latitude, longitude: mapLocation.longitude)) {
                                VStack(spacing: 0) {
//                                    Image(systemName: "shazam.logo.fill")
//                                        .resizable()
//                                        .foregroundColor(.blue)
//                                        .symbolRenderingMode(.hierarchical)
//                                        .frame(width: 48, height: 48)
//                                        .clipShape(Circle())
//                                        .padding(.bottom, 5)
                                    
                                    AsyncImage(
                                        url: mapLocation.artworkURL,
                                        content: { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 48, height: 48)
                                                .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                                        },
                                        placeholder: {
                                            ProgressView()
                                                .scaledToFit()
                                                .frame(width: 48, height: 48)
                                        }
                                    )

                                    Text(mapLocation.title)
                                        .fontWeight(.medium)
                                        .font(.system(size: 12))
                                        .opacity(0.80)
                                }
                                    .onTapGesture {
                                        selectedPlace = mapLocation
                                    }
                        }
                    })
                    .edgesIgnoringSafeArea(.top)
                    .environmentObject(location)
                
            case .restricted, .denied:
                Map(coordinateRegion: $region) // todo show relative area
                    .edgesIgnoringSafeArea(.top)
                    .environmentObject(location)
                
            default:
                Text("Location unavailable")
            }
        }
            .task {
                //location.requestPermission()
                if (location.authorizationStatus == .authorizedWhenInUse) {
                    region = location.region
                }
            }
            .task {
                convertLocs()
            }
            .sheet(item: $selectedPlace) { place in
                VStack(spacing: 0) {
                    HStack {
                        VStack(spacing: 0) {
                            AsyncImage(
                                url: selectedPlace?.artworkURL,
                                content: { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 148, height: 148)
                                        .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                                        .padding(.trailing, 5)
                                },
                                placeholder: {
                                    ProgressView()
                                        .scaledToFit()
                                        .frame(width: 148, height: 148)
                                        .padding(.trailing, 5)
                                }
                            )
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(selectedPlace?.title ?? "Loading…")
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                                .font(.system(size: 20))
                                .padding(.bottom, 3)
                            Text(selectedPlace?.artist ?? "…")
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.60))
                                .font(.system(size: 17))
                                .padding(.bottom, 3)
                            //                        Text(selectedPlace!.timestamp.formatted(.dateTime.day().month().hour().minute())) // fix
                            //                            .foregroundColor(Color.gray)
                            //                            .font(.system(size: 13))
                            Text((selectedPlace?.city ?? "…") + ", " + (selectedPlace?.country ?? "…"))
                                .foregroundColor(Color.gray)
                                .font(.system(size: 15))
                            Spacer()
                            
                            Button(action: { music.play(id: selectedPlace!.appleMusicID)}) {
                                Label("Listen", systemImage: "play.fill")
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 148)
                }
                    .presentationDetents([.medium])
            }
        // .onAppear(perform: { locationViewModel.requestPermission() })
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
